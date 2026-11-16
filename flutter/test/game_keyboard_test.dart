import 'package:flutter_hbb/mobile/widgets/game_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameKeyboardController', () {
    test('press and release use the ordinary HID route', () {
      final events = <(String, int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            events.add((character, usage, down)),
      );

      controller.press(1, 0x04);
      controller.release(1);

      expect(events, [('', 0x04, true), ('', 0x04, false)]);
    });

    test('same HID usage stays down until its final pointer releases', () {
      final events = <(String, int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            events.add((character, usage, down)),
      );

      controller.press(1, 0x1A);
      controller.press(2, 0x1A);
      controller.release(1);

      expect(events, [('', 0x1A, true)]);

      controller.release(2);
      expect(events, [('', 0x1A, true), ('', 0x1A, false)]);
    });

    test('reusing a pointer releases its previous HID usage first', () {
      final events = <(String, int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            events.add((character, usage, down)),
      );

      controller.press(1, 0x04);
      controller.press(1, 0x07);

      expect(events, [
        ('', 0x04, true),
        ('', 0x04, false),
        ('', 0x07, true),
      ]);
    });

    test('releaseAll releases each held HID usage once', () {
      final events = <(String, int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            events.add((character, usage, down)),
      );

      controller.press(1, 0x04);
      controller.press(2, 0x04);
      controller.press(3, 0x07);
      controller.releaseAll();
      controller.release(1);
      controller.release(2);
      controller.release(3);

      expect(events, [
        ('', 0x04, true),
        ('', 0x07, true),
        ('', 0x04, false),
        ('', 0x07, false),
      ]);
    });

    test('connection wait releases held keys before reconnect', () {
      final events = <(String, int, bool)>[];
      final controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            events.add((character, usage, down)),
      );

      controller.press(1, 0x1A);
      controller.onConnectionWaitingChanged(false);
      controller.onConnectionWaitingChanged(true);
      controller.press(1, 0x1A);

      expect(events, [
        ('', 0x1A, true),
        ('', 0x1A, false),
        ('', 0x1A, true),
      ]);
    });
  });

  group('game keyboard catalog', () {
    test('contains unique usages for the complete common PC keyboard', () {
      final usages = gameKeyboardRows
          .expand((row) => row)
          .map((key) => key.usbHidUsage)
          .toList();

      expect(usages, isNotEmpty);
      expect(usages, everyElement(greaterThan(0)));
      expect(usages.toSet(), hasLength(usages.length));
      expect(
        usages,
        containsAll(<int>{
          0x29,
          0x04,
          0x1D,
          0x1E,
          0x27,
          0x3A,
          0x45,
          0x49,
          0x4E,
          0x4F,
          0x50,
          0x51,
          0x52,
          0x53,
          0x54,
          0x58,
          0x59,
          0x63,
          0xE0,
          0xE1,
          0xE2,
          0xE3,
          0xE4,
          0xE5,
          0xE6,
          0xE7,
        }),
      );
      expect(
        usages.where((usage) => usage >= 0x3A && usage <= 0x45),
        hasLength(12),
      );
    });
  });

  group('GameKeyboard', () {
    late List<(String, int, bool)> events;
    late GameKeyboardController controller;

    setUp(() {
      final currentEvents = <(String, int, bool)>[];
      events = currentEvents;
      controller = GameKeyboardController(
        sendEvent: (character, usage, down) =>
            currentEvents.add((character, usage, down)),
      );
    });

    Future<void> pumpKeyboard(WidgetTester tester, {VoidCallback? onClose}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameKeyboard(
              controller: controller,
              onClose: onClose ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('a sustained pointer holds its HID key until release',
        (tester) async {
      await pumpKeyboard(tester);
      final w = find.byKey(const ValueKey<int>(0x1A));

      final gesture = await tester.startGesture(
        tester.getCenter(w),
        pointer: 10,
      );
      await tester.pump(const Duration(seconds: 2));

      expect(events, [('', 0x1A, true)]);

      await gesture.up();
      expect(events, [('', 0x1A, true), ('', 0x1A, false)]);
    });

    testWidgets('pointer cancellation releases its HID key', (tester) async {
      await pumpKeyboard(tester);
      final w = find.byKey(const ValueKey<int>(0x1A));

      final gesture = await tester.startGesture(
        tester.getCenter(w),
        pointer: 10,
      );
      await gesture.cancel();

      expect(events, [('', 0x1A, true), ('', 0x1A, false)]);
    });

    testWidgets('two pointers hold W and D simultaneously', (tester) async {
      await pumpKeyboard(tester);
      final w = find.byKey(const ValueKey<int>(0x1A));
      final d = find.byKey(const ValueKey<int>(0x07));

      final wGesture = await tester.startGesture(
        tester.getCenter(w),
        pointer: 10,
      );
      final dGesture = await tester.startGesture(
        tester.getCenter(d),
        pointer: 11,
      );

      expect(events, [('', 0x1A, true), ('', 0x07, true)]);

      await wGesture.up();
      expect(events, [
        ('', 0x1A, true),
        ('', 0x07, true),
        ('', 0x1A, false),
      ]);

      await dGesture.up();
      expect(events, [
        ('', 0x1A, true),
        ('', 0x07, true),
        ('', 0x1A, false),
        ('', 0x07, false),
      ]);
    });

    testWidgets('closing the keyboard releases held keys', (tester) async {
      var closed = false;
      await pumpKeyboard(tester, onClose: () => closed = true);
      final w = find.byKey(const ValueKey<int>(0x1A));
      final gesture = await tester.startGesture(
        tester.getCenter(w),
        pointer: 10,
      );

      await tester.tap(find.byKey(const ValueKey('game-keyboard-close')));

      expect(closed, isTrue);
      expect(events, [('', 0x1A, true), ('', 0x1A, false)]);
      await gesture.up();
    });

    testWidgets('scroll controls reveal keys beyond the narrow viewport',
        (tester) async {
      await pumpKeyboard(tester);
      final numpadNine = find.byKey(const ValueKey<int>(0x61));
      final initialX = tester.getCenter(numpadNine).dx;

      await tester.tap(
        find.byKey(const ValueKey('game-keyboard-scroll-right')),
      );
      await tester.pumpAndSettle();

      expect(tester.getCenter(numpadNine).dx, lessThan(initialX));
    });

    testWidgets('overlay isolates key pointers from remote gestures',
        (tester) async {
      var remotePointerDowns = 0;
      var remoteScaleUpdates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameKeyboardOverlay(
              remoteChild: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => remotePointerDowns++,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleUpdate: (_) => remoteScaleUpdates++,
                  child: const SizedBox.expand(),
                ),
              ),
              keyboard: GameKeyboard(
                controller: controller,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      final wGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<int>(0x1A))),
        pointer: 10,
      );
      final dGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<int>(0x07))),
        pointer: 11,
      );
      await wGesture.moveBy(const Offset(4, 0));
      await dGesture.moveBy(const Offset(-4, 0));
      await wGesture.up();
      await dGesture.up();

      expect(remotePointerDowns, 0);
      expect(remoteScaleUpdates, 0);
      expect(events, [
        ('', 0x1A, true),
        ('', 0x07, true),
        ('', 0x1A, false),
        ('', 0x07, false),
      ]);
    });

    testWidgets('removing the keyboard releases held keys', (tester) async {
      await pumpKeyboard(tester);
      final w = find.byKey(const ValueKey<int>(0x1A));
      final gesture = await tester.startGesture(
        tester.getCenter(w),
        pointer: 10,
      );

      await tester.pumpWidget(const SizedBox());

      expect(events, [('', 0x1A, true), ('', 0x1A, false)]);
      await gesture.up();
    });
  });
}
