import 'package:flutter_hbb/mobile/widgets/game_keyboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameKeyboardController', () {
    test('press and release send one HID key lifetime', () {
      final events = <(int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (usage, down) => events.add((usage, down)),
      );

      controller.press(1, 0x04);
      controller.release(1);

      expect(events, [(0x04, true), (0x04, false)]);
    });

    test('same HID usage stays down until its final pointer releases', () {
      final events = <(int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (usage, down) => events.add((usage, down)),
      );

      controller.press(1, 0x1A);
      controller.press(2, 0x1A);
      controller.release(1);

      expect(events, [(0x1A, true)]);

      controller.release(2);
      expect(events, [(0x1A, true), (0x1A, false)]);
    });

    test('reusing a pointer releases its previous HID usage first', () {
      final events = <(int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (usage, down) => events.add((usage, down)),
      );

      controller.press(1, 0x04);
      controller.press(1, 0x07);

      expect(events, [
        (0x04, true),
        (0x04, false),
        (0x07, true),
      ]);
    });

    test('releaseAll releases each held HID usage once', () {
      final events = <(int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (usage, down) => events.add((usage, down)),
      );

      controller.press(1, 0x04);
      controller.press(2, 0x04);
      controller.press(3, 0x07);
      controller.releaseAll();
      controller.release(1);
      controller.release(2);
      controller.release(3);

      expect(events, [
        (0x04, true),
        (0x07, true),
        (0x04, false),
        (0x07, false),
      ]);
    });
  });
}
