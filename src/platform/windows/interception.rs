const INTERCEPTION_KEY_UP: u16 = 0x01;
const INTERCEPTION_KEY_E0: u16 = 0x02;
const INTERCEPTION_KEY_E1: u16 = 0x04;
const INTERCEPTION_MAX_KEYBOARD: i32 = 10;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(C)]
struct InterceptionKeyStroke {
    code: u16,
    state: u16,
    information: u32,
}

fn stroke_from_scan_code(scan_code: u32, down: bool) -> Option<InterceptionKeyStroke> {
    if scan_code > u16::MAX as u32 {
        return None;
    }

    let code = (scan_code & 0xFF) as u16;
    if code == 0 {
        return None;
    }

    let mut state = match scan_code >> 8 {
        0x00 => 0,
        0xE0 => INTERCEPTION_KEY_E0,
        0xE1 => INTERCEPTION_KEY_E1,
        _ => return None,
    };
    if !down {
        state |= INTERCEPTION_KEY_UP;
    }

    Some(InterceptionKeyStroke {
        code,
        state,
        information: 0,
    })
}

fn first_keyboard_device(mut hardware_id_size: impl FnMut(i32) -> u32) -> Option<i32> {
    (1..=INTERCEPTION_MAX_KEYBOARD).find(|&device| hardware_id_size(device) > 0)
}

#[cfg(windows)]
mod runtime {
    use super::{first_keyboard_device, stroke_from_scan_code, InterceptionKeyStroke};
    use hbb_common::libloading::Library;
    use std::{ffi::c_void, sync::Mutex, time::Duration};

    type InterceptionContext = *mut c_void;
    type CreateContext = unsafe extern "C" fn() -> InterceptionContext;
    type DestroyContext = unsafe extern "C" fn(InterceptionContext);
    type SendStroke = unsafe extern "C" fn(InterceptionContext, i32, *const c_void, u32) -> i32;
    type GetHardwareId = unsafe extern "C" fn(InterceptionContext, i32, *mut c_void, u32) -> u32;

    struct Api {
        _library: Library,
        create_context: CreateContext,
        destroy_context: DestroyContext,
        send: SendStroke,
        get_hardware_id: GetHardwareId,
    }

    impl Api {
        fn load() -> Result<Self, String> {
            let executable = std::env::current_exe()
                .map_err(|error| format!("failed to locate rustdesk.exe: {error}"))?;
            let directory = executable
                .parent()
                .ok_or_else(|| "rustdesk.exe has no parent directory".to_owned())?;
            let library_path = directory.join("interception.dll");
            if !library_path.is_absolute() {
                return Err("interception.dll path is not absolute".to_owned());
            }

            let library = unsafe { Library::new(&library_path) }
                .map_err(|error| format!("failed to load {}: {error}", library_path.display()))?;
            let create_context =
                unsafe { load_symbol(&library, b"interception_create_context\0") }?;
            let destroy_context =
                unsafe { load_symbol(&library, b"interception_destroy_context\0") }?;
            let send = unsafe { load_symbol(&library, b"interception_send\0") }?;
            let get_hardware_id =
                unsafe { load_symbol(&library, b"interception_get_hardware_id\0") }?;

            Ok(Self {
                _library: library,
                create_context,
                destroy_context,
                send,
                get_hardware_id,
            })
        }
    }

    unsafe fn load_symbol<T: Copy>(library: &Library, name: &[u8]) -> Result<T, String> {
        library
            .get::<T>(name)
            .map(|symbol| *symbol)
            .map_err(|error| {
                let display_name = String::from_utf8_lossy(name)
                    .trim_end_matches('\0')
                    .to_owned();
                format!("failed to resolve {display_name}: {error}")
            })
    }

    struct Backend {
        api: Api,
        context: InterceptionContext,
        device: i32,
    }

    // Every access to the context is serialized by BACKEND.
    unsafe impl Send for Backend {}

    impl Backend {
        fn new() -> Result<Self, String> {
            let api = Api::load()?;
            let context = unsafe { (api.create_context)() };
            if context.is_null() {
                return Err(
                    "driver context is unavailable; install the driver and reboot".to_owned(),
                );
            }

            let mut hardware_id = [0u8; 512];
            let device = first_keyboard_device(|device| unsafe {
                (api.get_hardware_id)(
                    context,
                    device,
                    hardware_id.as_mut_ptr().cast(),
                    hardware_id.len() as u32,
                )
            });
            let Some(device) = device else {
                unsafe { (api.destroy_context)(context) };
                return Err("no attached Interception keyboard device was found".to_owned());
            };

            Ok(Self {
                api,
                context,
                device,
            })
        }

        fn send(&self, stroke: &InterceptionKeyStroke) -> bool {
            unsafe {
                (self.api.send)(
                    self.context,
                    self.device,
                    (stroke as *const InterceptionKeyStroke).cast(),
                    1,
                ) == 1
            }
        }
    }

    impl Drop for Backend {
        fn drop(&mut self) {
            unsafe { (self.api.destroy_context)(self.context) };
        }
    }

    enum BackendState {
        Uninitialized,
        Ready(Backend),
        Unavailable(String),
    }

    lazy_static::lazy_static! {
        static ref BACKEND: Mutex<BackendState> = Mutex::new(BackendState::Uninitialized);
    }

    pub(super) fn send_scan_code(scan_code: u32, down: bool) -> bool {
        let Some(stroke) = stroke_from_scan_code(scan_code, down) else {
            warn_unavailable(&format!("unsupported Windows scan code {scan_code:#X}"));
            return false;
        };

        let mut state = BACKEND.lock().unwrap();
        if matches!(*state, BackendState::Uninitialized) {
            *state = match Backend::new() {
                Ok(backend) => BackendState::Ready(backend),
                Err(error) => BackendState::Unavailable(error),
            };
        }

        match &*state {
            BackendState::Ready(backend) if backend.send(&stroke) => true,
            BackendState::Ready(_) => {
                warn_unavailable("driver rejected the keyboard stroke");
                false
            }
            BackendState::Unavailable(error) => {
                warn_unavailable(error);
                false
            }
            BackendState::Uninitialized => false,
        }
    }

    fn warn_unavailable(reason: &str) {
        hbb_common::throttled_log!(
            Duration::from_secs(60),
            warn,
            "Interception Map Mode unavailable, using SendInput fallback: {reason}"
        );
    }
}

#[cfg(windows)]
pub(crate) fn send_scan_code(scan_code: u32, down: bool) -> bool {
    runtime::send_scan_code(scan_code, down)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ordinary_scan_code_preserves_make_code_and_down_up_state() {
        let down = stroke_from_scan_code(0x001E, true).unwrap();
        let up = stroke_from_scan_code(0x001E, false).unwrap();

        assert_eq!(down.code, 0x1E);
        assert_eq!(down.state, 0x00);
        assert_eq!(up.code, 0x1E);
        assert_eq!(up.state, 0x01);
    }

    #[test]
    fn extended_scan_code_preserves_e0_prefix_and_down_up_state() {
        let down = stroke_from_scan_code(0xE04D, true).unwrap();
        let up = stroke_from_scan_code(0xE04D, false).unwrap();

        assert_eq!(down.code, 0x4D);
        assert_eq!(down.state, 0x02);
        assert_eq!(up.code, 0x4D);
        assert_eq!(up.state, 0x03);
    }

    #[test]
    fn e1_scan_code_preserves_e1_prefix() {
        let stroke = stroke_from_scan_code(0xE11D, true).unwrap();

        assert_eq!(stroke.code, 0x1D);
        assert_eq!(stroke.state, 0x04);
    }

    #[test]
    fn malformed_scan_codes_are_rejected() {
        assert!(stroke_from_scan_code(0, true).is_none());
        assert!(stroke_from_scan_code(0x1234, true).is_none());
        assert!(stroke_from_scan_code(0x1_001E, true).is_none());
    }

    #[test]
    fn first_attached_keyboard_device_is_selected() {
        assert_eq!(
            first_keyboard_device(|device| u32::from(device == 1)),
            Some(1)
        );
        assert_eq!(
            first_keyboard_device(|device| u32::from(device == 4)),
            Some(4)
        );
    }

    #[test]
    fn no_attached_keyboard_device_returns_none() {
        assert_eq!(first_keyboard_device(|_| 0), None);
    }
}
