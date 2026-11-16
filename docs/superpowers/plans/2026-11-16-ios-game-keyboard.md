# iOS Game Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete multitouch game keyboard overlay to the iPhone remote-control page using RustDesk's existing HID Map Mode events.

**Architecture:** A self-contained mobile widget owns the fixed HID key catalog and translates raw Flutter pointer lifetimes into a small reference-counted controller. `RemotePage` only toggles the overlay and releases the controller at session and application lifecycle boundaries, leaving existing input paths unchanged when the feature is hidden.

**Tech Stack:** Dart 3.1, Flutter 3.24.5, Flutter widget tests, RustDesk `InputModel.newKeyboardMode`

**Spec:** `docs/superpowers/specs/2026-11-16-ios-game-keyboard-design.md`

## Global Constraints

- Use explicit USB HID keyboard-page usages and the existing Map Mode API; do not change Rust, Windows input code, the protocol, or the server.
- Preserve the existing text keyboard and all remote-control behavior while the game overlay is hidden.
- Support long holds, simultaneous pointers, pointer cancellation, and deterministic release of every held key.
- Keep the first version to one fixed, scrollable full-PC-keyboard layout; do not add profiles, macros, drag editing, dependencies, or localization keys.
- Put Dart tests in `flutter/test/*_test.dart` and do not run `flutter_rust_bridge_codegen`.

## Review Focus

- A second finger pressing an already-held usage must not cause an early remote key-up when the first finger lifts; Task 1 tests reference counting.
- A pointer reused for a different key must release the old usage before pressing the new one; Task 1 tests event order.
- An iOS pointer cancellation or widget removal during a hold must release the remote key; Task 2 tests cancellation and disposal.
- Two distinct fingers must hold `W+D` concurrently without gesture recognizers converting the action into taps; Task 2 uses raw pointer gestures.
- Closing, disconnecting, or backgrounding during a hold must not leave a remote key down; Tasks 2 and 3 cover widget close/removal and remote lifecycle hooks.

---

### Task 1: HID key state controller

**Files:**
- Create: `flutter/lib/mobile/widgets/game_keyboard.dart`
- Create: `flutter/test/game_keyboard_test.dart`

**Interfaces:**
- Consumes: `void Function(int usbHidUsage, bool down)` supplied by the remote page.
- Produces: `GameKeyboardController({required GameKeyboardEventSender sendEvent})`, `press(int pointerId, int usbHidUsage)`, `release(int pointerId)`, and `releaseAll()`.

- [ ] **Step 1: Write failing controller tests**

Add tests named `press and release send one HID key lifetime`, `same HID usage stays down until its final pointer releases`, `reusing a pointer releases its previous HID usage first`, and `releaseAll releases each held HID usage once`. Assert literal ordered `(usage, down)` events.

- [ ] **Step 2: Run the controller tests to verify RED**

Run: `flutter test test/game_keyboard_test.dart --plain-name 'press and release send one HID key lifetime'` from `flutter/`

Expected: FAIL because `game_keyboard.dart` and `GameKeyboardController` do not exist.

- [ ] **Step 3: Implement the minimal controller**

Use a pointer-to-usage map plus a usage reference-count map. State changes occur before invoking `sendEvent`, and `releaseAll()` emits one up event per held usage.

- [ ] **Step 4: Run all controller tests to verify GREEN**

Run: `flutter test test/game_keyboard_test.dart`

Expected: all controller tests PASS.

- [ ] **Step 5: Commit**

Commit: `feat: add game keyboard HID controller`

### Task 2: Complete multitouch keyboard overlay

**Files:**
- Modify: `flutter/lib/mobile/widgets/game_keyboard.dart`
- Modify: `flutter/test/game_keyboard_test.dart`

**Interfaces:**
- Consumes: `GameKeyboardController` from Task 1.
- Produces: immutable `gameKeyboardRows`, `GameKeyboard({required controller, required onClose})`, HID-keyed button widgets, and overlay close/disposal cleanup.

- [ ] **Step 1: Write failing catalog and widget tests**

Test that the catalog has unique nonzero usages and literal coverage for Escape, letters, digits, F1-F12, arrows, left/right modifiers, navigation keys, and numeric keypad. Add raw-pointer widget tests for a sustained hold, pointer cancellation, simultaneous `W+D`, close while held, and removal while held.

- [ ] **Step 2: Run the new tests to verify RED**

Run: `flutter test test/game_keyboard_test.dart`

Expected: FAIL because the catalog and `GameKeyboard` widget do not exist.

- [ ] **Step 3: Implement the fixed overlay**

Build six keyboard rows from explicit USB HID usage literals. Use `Listener` callbacks for pointer down/up/cancel, a stable `ValueKey` per usage, horizontal scrolling for narrow screens, and a close control. Releasing/disposing the overlay calls `releaseAll()`.

- [ ] **Step 4: Run widget and catalog tests to verify GREEN**

Run: `flutter test test/game_keyboard_test.dart`

Expected: all tests PASS with no exception output.

- [ ] **Step 5: Commit**

Commit: `feat: add multitouch game keyboard overlay`

### Task 3: Remote page integration and lifecycle release

**Files:**
- Modify: `flutter/lib/mobile/pages/remote_page.dart`
- Test: `flutter/test/game_keyboard_test.dart`

**Interfaces:**
- Consumes: `GameKeyboardController`, `GameKeyboard`, `kKeyFlutterKey`, and `InputModel.newKeyboardMode(String, int, bool, bool)`.
- Produces: a toolbar toggle for non-Android peers and release hooks for close, disconnect, disposal, and non-resumed app lifecycle states.

- [ ] **Step 1: Verify the widget lifecycle test is RED before integration**

Run: `flutter test test/game_keyboard_test.dart --plain-name 'removing the keyboard releases held keys'`

Expected: PASS after Task 2; this is the tested ownership boundary the thin page hook relies on.

- [ ] **Step 2: Integrate the overlay into `RemotePage`**

Initialize the controller with `inputModel.newKeyboardMode(kKeyFlutterKey, usage, down, false)`. Add a `sports_esports` toolbar toggle beside the text keyboard, render the overlay last in the mobile image stack, make text and game keyboards mutually exclusive, and call `releaseAll()` before close/disposal, when `pi.isSet` becomes false, and whenever the app is not resumed.

- [ ] **Step 3: Format and statically analyze the changed Dart files**

Run: `dart format lib/mobile/widgets/game_keyboard.dart lib/mobile/pages/remote_page.dart test/game_keyboard_test.dart`

Expected: formatter succeeds.

Run: `flutter analyze lib/mobile/widgets/game_keyboard.dart lib/mobile/pages/remote_page.dart test/game_keyboard_test.dart`

Expected: no new analyzer errors.

- [ ] **Step 4: Run focused and full Flutter tests**

Run: `flutter test test/game_keyboard_test.dart`

Expected: all game keyboard tests PASS.

Run: `flutter test`

Expected: the existing Flutter suite and new tests PASS, or any unrelated baseline failure is recorded verbatim.

- [ ] **Step 5: Commit**

Commit: `feat: integrate iOS game keyboard`
