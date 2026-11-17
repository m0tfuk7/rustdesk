# iOS Game Keyboard Design

## Goal

Add an optional game keyboard overlay to the RustDesk mobile remote-control page so an iPhone can hold and combine ordinary PC keys while controlling a Windows game. The existing text keyboard remains unchanged.

## User experience

- A game-controller button appears beside the existing keyboard button for non-Android remote peers that permit keyboard input.
- Tapping it opens a fixed, scrollable PC keyboard overlay over the remote image. Tapping the close button returns to the ordinary remote-control view.
- The overlay exposes a standard ANSI TKL 87-key keyboard: Escape, F1-F12, alphanumeric and punctuation keys, modifiers, navigation keys, arrows, and Windows/Menu keys. It omits the numeric keypad.
- Function-key groups, standard-width Backspace/Backslash/Enter/Shift keys, the six-key navigation block, and the inverted-T arrow cluster retain their familiar spacing and alignment instead of being packed together.
- Each key stays pressed for the lifetime of the finger touching it. Multiple fingers can hold different keys, so combinations such as `W+D`, `Shift+W`, and `Ctrl+Alt+Delete` work.
- The existing native text keyboard continues to handle chat and normal text entry. The game overlay and native text keyboard are mutually exclusive.

## Input protocol

The overlay sends the existing Map Mode protocol through `InputModel.newKeyboardMode`. Every key is represented by its USB HID keyboard-page usage and sends an explicit `KeyDown` on pointer down and `KeyUp` on pointer up or cancellation. No Rust, Windows input, or RustDesk Server changes are required.

The input state controller tracks both pointer-to-key ownership and a reference count per HID usage. Reusing a pointer for another key first releases its old key. If multiple pointers press the same key, only the first sends `KeyDown` and only the last release sends `KeyUp`.

## Safety and lifecycle

All held keys are released when the overlay closes or is removed, the remote page closes, the peer disconnects, or the app leaves the foreground. This prevents a remotely stuck movement or modifier key. A normal pointer cancellation also releases its individual key.

## Scope

The first version uses one fixed ANSI TKL 87-key layout with horizontal scrolling on narrow screens. It does not include a numeric keypad, layout editing, draggable keys, saved profiles, macros, or server changes. The feature is additive: when the overlay is hidden, the existing text, physical-keyboard, mouse, and gesture paths retain their current implementation.

## Files

- `flutter/lib/mobile/widgets/game_keyboard.dart`: HID catalog, pointer state controller, and overlay widgets.
- `flutter/lib/mobile/pages/remote_page.dart`: toolbar entry and remote-session lifecycle hooks.
- `flutter/test/game_keyboard_test.dart`: controller, multitouch, cancellation, lifecycle, and key-catalog tests.
