# Windows Interception Map Mode Design

## Intent

Make RustDesk Map Mode keyboard input work in Windows games that ignore Win32 `SendInput`, while keeping the existing RustDesk protocol and controller behavior unchanged. This is for personal, non-commercial use.

## Goals

- On a controlled Windows host, inject existing Map Mode scan-code down/up events through Interception.
- Preserve the current Map Mode protocol, menu entry, HID mapping, and modifier behavior.
- Fall back to the current `rdev`/`SendInput` path whenever Interception is unavailable or rejects an event.
- Release Map Mode keys through the same Interception-first path during timeout and shutdown cleanup.
- Keep macOS builds compatible without adding macOS-specific behavior.

## Non-goals

- No new Game Mode, keyboard-mode enum, wire message, or desktop UI.
- No changes to Legacy Mode, Translate Mode, Unicode text input, or mouse injection.
- No automatic driver installation from RustDesk and no attempt to bypass anti-cheat software.
- No guarantee for games or anti-cheat systems that block the Interception driver.

## Constraints

- Interception v1.0.1 is used through its official DLL API. The DLL and driver remain external vendor assets.
- The official project licenses non-commercial use under its stated LGPL terms; commercial distribution requires the author's commercial license.
- Driver installation requires an elevated Windows terminal and normally a reboot. Normal RustDesk launches should not require elevation after installation.
- Windows ARM64 is not a delivery target because the official v1.0.1 package supplies x86 and x64 user-mode binaries and drivers, not ARM64 assets.
- The loader must use an absolute path beside `rustdesk.exe`; it must not search the current working directory or `PATH`.

## Approaches

1. **Replace all Windows keyboard injection globally.** Rejected because Legacy/Translate text input and unrelated shortcuts still benefit from the established Enigo/SendInput behavior.
2. **Add a new Game keyboard mode and protocol value.** Rejected because the existing Map Mode already carries the required Windows scan codes and down/up state. It would add compatibility and UI work without improving injection.
3. **Replace only the Windows Map Mode injection backend.** Selected because it is the smallest change and directly addresses games that ignore SendInput.

## Design

`src/platform/windows/interception.rs` owns the Windows-only runtime backend. It dynamically loads `interception.dll` from the directory containing the running executable, resolves only the official context, send, hardware-id, and destroy functions, creates one serialized context, and chooses the first attached keyboard device reported by the driver.

The backend converts RustDesk's Windows scan-code representation into `InterceptionKeyStroke`: the low byte is the make code, `0xE0` and `0xE1` prefixes become the corresponding state flags, and key-up adds the key-up flag. Unsupported encodings are rejected so the caller can use the existing fallback. A successful send means exactly one stroke was written. Initialization and repeated access are protected by a mutex because the input service can be reached from multiple threads.

`src/server/input_service.rs` keeps the current Map Mode routing. On Windows only, its raw-position injection first calls the Interception backend; failure continues into the unchanged `rdev::simulate` path. Windows Map Mode keys are recorded by scan code rather than by the fallback's `RawKey`, so forced cleanup retries Interception first and falls back in the same way as the original event. Other platforms and keyboard modes retain their existing paths.

An administrator-run setup script downloads the official v1.0.1 package, verifies the pinned SHA-256, installs the driver, and copies the x64 DLL beside the selected RustDesk executable. The script is an explicit setup step and is never run automatically by RustDesk.

## Verification

- Unit tests cover ordinary, key-up, `E0`, `E1`, invalid scan-code conversion, and keyboard-device selection.
- Windows tests compile the runtime loader and confirm the fallback build remains available without the DLL or driver.
- A Windows x64 smoke test verifies Notepad input without Interception, then Map Mode keydown/keyup in a non-anti-cheat game after installing the driver and rebooting.
- The macOS build/test path confirms the Windows-only module does not affect the controller build.
