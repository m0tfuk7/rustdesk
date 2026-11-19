# Windows Interception Map Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route RustDesk Map Mode scan-code input through Interception on controlled Windows x64 hosts, with the existing SendInput path as fallback.

**Architecture:** Add a focused Windows-only runtime loader for the official Interception DLL and call it from the existing Map Mode raw-key path. Keep the protocol, UI, macOS controller, other keyboard modes, and mouse path unchanged.

**Tech Stack:** Rust 2021, `hbb_common::libloading`, Interception v1.0.1 DLL API, PowerShell setup script

**Spec:** `docs/superpowers/specs/2026-11-18-windows-interception-map-mode-design.md`

## Global Constraints

- Use the official Interception v1.0.1 DLL API only; do not reimplement its private driver IOCTL protocol.
- Load only an absolute `interception.dll` path beside the running executable.
- Keep Legacy Mode, Translate Mode, Unicode input, mouse input, protocol enums, and Flutter UI unchanged.
- A missing DLL, missing driver, absent physical keyboard, invalid scan code, or failed send must use the existing `rdev`/SendInput fallback.
- Do not bundle vendor binaries or run the driver installer automatically from RustDesk.
- Windows x64 is the Interception delivery target; macOS behavior remains unchanged.

## Review Focus

- Extended navigation keys such as arrows (`0xE0xx`) must retain their prefix on both down and up. Covered by Task 1 conversion tests.
- A DLL present without an installed/rebooted driver must fail initialization once and fall back without dropping the key. Covered by Task 2 Windows smoke test.
- A host without an attached keyboard must fall back rather than selecting a nonexistent device. Covered by Task 1 device-selection tests.
- A key held when RustDesk exits must be released through Interception-first injection. Covered by Task 2 cleanup-path review and smoke test.
- macOS and non-Windows Map Mode builds must compile without linking or loading Interception. Covered by Task 3 macOS verification.

---

### Task 1: Windows Interception runtime backend

**Files:**
- Create: `src/platform/windows/interception.rs`
- Modify: `src/platform/windows.rs`
- Test: `src/platform/windows/interception.rs` (`#[cfg(test)]` module)

**Interfaces:**
- Consumes: Windows scan codes encoded as `0x00xx`, `0xE0xx`, or `0xE1xx`, plus down/up state.
- Produces: `pub(crate) fn send_scan_code(scan_code: u32, down: bool) -> bool`. `true` means exactly one Interception stroke was sent; `false` requires caller fallback.

- [ ] **Step 1: Write failing conversion and device-selection tests**

Add tests asserting `stroke_from_scan_code` maps `0x001E` down/up to states `0x00`/`0x01`, `0xE04D` down/up to `0x02`/`0x03`, `0xE11D` to `0x04`, and rejects zero, prefixes other than `0x00`, `0xE0`, or `0xE1`, and values above `u16`. Also assert `first_keyboard_device` selects device 1 when present, skips absent devices and selects the first later device, and returns `None` when all ten are absent.

- [ ] **Step 2: Run the focused tests and confirm failure**

Run on Windows: `cargo test --lib platform::windows::interception::tests --no-default-features`

Expected: FAIL because the module/helper does not exist.

- [ ] **Step 3: Implement stroke conversion and device selection**

In `src/platform/windows/interception.rs`, define the `#[repr(C)] InterceptionKeyStroke`, state constants, `fn stroke_from_scan_code(scan_code: u32, down: bool) -> Option<InterceptionKeyStroke>`, and `fn first_keyboard_device(mut hardware_id_size: impl FnMut(i32) -> u32) -> Option<i32>`. Device candidates are exactly `1..=10`; select the first returning a nonzero hardware-id size.

- [ ] **Step 4: Implement the dynamic backend**

Resolve `interception_create_context`, `interception_destroy_context`, `interception_send`, and `interception_get_hardware_id` from an absolute sibling `interception.dll`. Keep the library alive with the function pointers, serialize a single lazy backend with `Mutex`, destroy its context on drop, and make `send_scan_code` return `false` for every initialization, conversion, device-selection, or one-stroke send failure. Log unavailability with a throttled warning rather than once per key event.

- [ ] **Step 5: Run focused tests**

Run on Windows: `cargo test --lib platform::windows::interception::tests --no-default-features`

Expected: all Task 1 tests PASS.

### Task 2: Route Windows Map Mode and cleanup through Interception

**Files:**
- Modify: `src/server/input_service.rs`
- Test: Windows fallback and cleanup smoke tests

**Interfaces:**
- Consumes: `platform::windows::interception::send_scan_code(scan_code, down)` from Task 1.
- Produces: Windows Map Mode Interception-first injection with existing `simulate_` fallback and a Windows-only `KeysDown::MapScanCode(KeyCode)` cleanup record.

- [ ] **Step 1: Verify the current cleanup path does not know Map Mode scan codes**

Inspect `KeysDown`, `sim_rdev_rawkey_position`, and `release_record_key`; record that Windows Map Mode currently stores `RawKey` and cleanup calls the generic `simulate_` path. This is the failing behavior the smoke test will distinguish after implementation.

- [ ] **Step 2: Implement the thin Map Mode hook**

For Windows only, record Map Mode positions as `KeysDown::MapScanCode(KeyCode)`. Inject through `send_scan_code(code as u32, down)` and return on success; otherwise call the existing `simulate_` event unchanged. In `release_record_key`, release `MapScanCode` through the same Interception-first helper without recording it again. Leave non-Windows `RdevKey` recording and every non-Map path untouched.

- [ ] **Step 3: Run full Windows library tests**

Run:

```powershell
cargo test --locked --release --lib --features "flutter,hwcodec"
```

Expected: all tests PASS with no `interception.dll` installed, proving compilation and fallback do not require the vendor asset.

- [ ] **Step 4: Perform Windows fallback and cleanup smoke tests**

Run the x64 build without `interception.dll`, connect in Map Mode, and verify ordinary keys plus arrow down/up work in Notepad. Confirm one throttled unavailability warning appears and input is not dropped. Then repeat with Interception installed: hold an arrow key, end the RustDesk process/session, and verify the game stops moving when cleanup runs.

### Task 3: Explicit Windows setup and cross-platform verification

**Files:**
- Create: `res/interception/setup-interception.ps1`
- Create: `res/interception/README.md`

**Interfaces:**
- Consumes: official v1.0.1 release URL, pinned SHA-256 `ad038963d6413055765128b0b931f6e765147c9916dba79e65d872b261f9af10`, and a user-supplied RustDesk installation directory.
- Produces: an explicit elevated setup command that installs the official driver and copies `library/x64/interception.dll` beside `rustdesk.exe`.

- [ ] **Step 1: Implement the setup script**

Add parameters for the RustDesk directory and optional download cache. Require an elevated process, download over HTTPS, verify the exact SHA-256 before extraction, copy only the official x64 DLL beside `rustdesk.exe`, run `install-interception.exe /install`, and state that Windows must reboot. Fail without changing the RustDesk directory when validation fails.

- [ ] **Step 2: Document setup, rollback, and license boundary**

Document the one-time administrator setup, reboot, normal non-elevated use, how to remove the sibling DLL to force fallback, the official `/uninstall` command, the non-commercial-use limitation, and the fact that anti-cheat compatibility is not guaranteed.

- [ ] **Step 3: Validate PowerShell syntax on Windows**

Run: `powershell -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw 'res/interception/setup-interception.ps1'))"`

Expected: exit code 0.

- [ ] **Step 4: Verify macOS remains unchanged**

Run on macOS:

```bash
FEATURES=$(./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit --print-features)
cargo test --locked --release --lib --features "$FEATURES"
```

Expected: all tests PASS without any Interception asset or linker input.

- [ ] **Step 5: Perform Windows Interception smoke test**

After running the setup script and rebooting, connect from the existing macOS client in Map Mode. Verify separate keydown/keyup for letters, Shift, Ctrl, Enter, and arrow keys in a non-anti-cheat game; disconnect while holding a key and confirm it is released.

### Task 4: Regression-surface review

**Files:**
- Review only; remove any unrelated edits before completion.

**Interfaces:**
- Consumes: final diff and verification output from Tasks 1-3.
- Produces: a minimal final diff and an explicit regression-surface report.

- [ ] **Step 1: Inspect the final diff**

Run: `git diff --check && git diff --stat && git diff -- src/platform/windows.rs src/platform/windows/interception.rs src/server/input_service.rs res/interception docs/superpowers`

Expected: no whitespace errors and no edits to protocol, Flutter UI, Enigo, Legacy Mode, Translate Mode, mouse paths, or macOS platform files.

- [ ] **Step 2: Report unavoidable behavior changes**

List only: Windows Map Mode raw scan-code injection, Windows Map Mode held-key cleanup, optional same-directory DLL loading, and the explicit administrator setup script. Confirm that absent/unsupported Interception retains the old runtime path.
