import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef GameKeyboardEventSender = void Function(
    String character, int usbHidUsage, bool down);

class GameKeyboardController {
  GameKeyboardController({required this.sendEvent});

  final GameKeyboardEventSender sendEvent;
  final Map<int, int> _pointerUsages = {};
  final Map<int, int> _usageRefCounts = {};

  void press(int pointerId, int usbHidUsage) {
    final previousUsage = _pointerUsages[pointerId];
    if (previousUsage == usbHidUsage) {
      return;
    }
    if (previousUsage != null) {
      release(pointerId);
    }

    _pointerUsages[pointerId] = usbHidUsage;
    final refCount = (_usageRefCounts[usbHidUsage] ?? 0) + 1;
    _usageRefCounts[usbHidUsage] = refCount;
    if (refCount == 1) {
      sendEvent('', usbHidUsage, true);
    }
  }

  void release(int pointerId) {
    final usage = _pointerUsages.remove(pointerId);
    if (usage == null) {
      return;
    }

    final refCount = _usageRefCounts[usage];
    if (refCount == null || refCount <= 1) {
      _usageRefCounts.remove(usage);
      sendEvent('', usage, false);
    } else {
      _usageRefCounts[usage] = refCount - 1;
    }
  }

  void releaseAll() {
    final usages = _usageRefCounts.keys.toList();
    _pointerUsages.clear();
    _usageRefCounts.clear();
    for (final usage in usages) {
      sendEvent('', usage, false);
    }
  }

  void onConnectionWaitingChanged(bool waiting) {
    if (waiting) {
      releaseAll();
    }
  }
}

class GameKeyboardKey {
  const GameKeyboardKey(
    this.label,
    this.usbHidUsage, {
    this.width = 1,
    this.gapBefore = 0,
  });

  final String label;
  final int usbHidUsage;
  final double width;
  final double gapBefore;
}

const double _gameKeyboardScale = 2 / 3;
const double _gameKeyboardUnit = 44 * _gameKeyboardScale;
const double _gameKeyboardMaxHeight = 300 * _gameKeyboardScale;
const double _gameKeyboardMaxKeyHeight = 38 * _gameKeyboardScale;
const double _gameKeyboardRightGap = 3;

const List<List<GameKeyboardKey>> gameKeyboardRows = [
  [
    GameKeyboardKey('Esc', 0x29),
    GameKeyboardKey('F1', 0x3A, gapBefore: _gameKeyboardUnit),
    GameKeyboardKey('F2', 0x3B),
    GameKeyboardKey('F3', 0x3C),
    GameKeyboardKey('F4', 0x3D),
    GameKeyboardKey('F5', 0x3E, gapBefore: _gameKeyboardUnit * 0.5),
    GameKeyboardKey('F6', 0x3F),
    GameKeyboardKey('F7', 0x40),
    GameKeyboardKey('F8', 0x41),
    GameKeyboardKey('F9', 0x42, gapBefore: _gameKeyboardUnit * 0.5),
    GameKeyboardKey('F10', 0x43),
    GameKeyboardKey('F11', 0x44),
    GameKeyboardKey('F12', 0x45),
    GameKeyboardKey('PrtSc', 0x46, gapBefore: _gameKeyboardRightGap),
    GameKeyboardKey('ScrLk', 0x47),
    GameKeyboardKey('Pause', 0x48),
  ],
  [
    GameKeyboardKey('`', 0x35),
    GameKeyboardKey('1', 0x1E),
    GameKeyboardKey('2', 0x1F),
    GameKeyboardKey('3', 0x20),
    GameKeyboardKey('4', 0x21),
    GameKeyboardKey('5', 0x22),
    GameKeyboardKey('6', 0x23),
    GameKeyboardKey('7', 0x24),
    GameKeyboardKey('8', 0x25),
    GameKeyboardKey('9', 0x26),
    GameKeyboardKey('0', 0x27),
    GameKeyboardKey('-', 0x2D),
    GameKeyboardKey('=', 0x2E),
    GameKeyboardKey('Backspace', 0x2A, width: 2),
    GameKeyboardKey('Ins', 0x49, gapBefore: _gameKeyboardRightGap),
    GameKeyboardKey('Home', 0x4A),
    GameKeyboardKey('PgUp', 0x4B),
  ],
  [
    GameKeyboardKey('Tab', 0x2B, width: 1.5),
    GameKeyboardKey('Q', 0x14),
    GameKeyboardKey('W', 0x1A),
    GameKeyboardKey('E', 0x08),
    GameKeyboardKey('R', 0x15),
    GameKeyboardKey('T', 0x17),
    GameKeyboardKey('Y', 0x1C),
    GameKeyboardKey('U', 0x18),
    GameKeyboardKey('I', 0x0C),
    GameKeyboardKey('O', 0x12),
    GameKeyboardKey('P', 0x13),
    GameKeyboardKey('[', 0x2F),
    GameKeyboardKey(']', 0x30),
    GameKeyboardKey('\\ |', 0x31, width: 1.5),
    GameKeyboardKey('Del', 0x4C, gapBefore: _gameKeyboardRightGap),
    GameKeyboardKey('End', 0x4D),
    GameKeyboardKey('PgDn', 0x4E),
  ],
  [
    GameKeyboardKey('Caps', 0x39, width: 1.75),
    GameKeyboardKey('A', 0x04),
    GameKeyboardKey('S', 0x16),
    GameKeyboardKey('D', 0x07),
    GameKeyboardKey('F', 0x09),
    GameKeyboardKey('G', 0x0A),
    GameKeyboardKey('H', 0x0B),
    GameKeyboardKey('J', 0x0D),
    GameKeyboardKey('K', 0x0E),
    GameKeyboardKey('L', 0x0F),
    GameKeyboardKey(';', 0x33),
    GameKeyboardKey("'", 0x34),
    GameKeyboardKey('Enter', 0x28, width: 2.25),
  ],
  [
    GameKeyboardKey('L Shift', 0xE1, width: 2.25),
    GameKeyboardKey('Z', 0x1D),
    GameKeyboardKey('X', 0x1B),
    GameKeyboardKey('C', 0x06),
    GameKeyboardKey('V', 0x19),
    GameKeyboardKey('B', 0x05),
    GameKeyboardKey('N', 0x11),
    GameKeyboardKey('M', 0x10),
    GameKeyboardKey(',', 0x36),
    GameKeyboardKey('.', 0x37),
    GameKeyboardKey('/', 0x38),
    GameKeyboardKey('R Shift', 0xE5, width: 2.75),
    GameKeyboardKey(
      '↑',
      0x52,
      gapBefore: _gameKeyboardUnit + _gameKeyboardRightGap,
    ),
  ],
  [
    GameKeyboardKey('L Ctrl', 0xE0, width: 1.25),
    GameKeyboardKey('L Win', 0xE3, width: 1.25),
    GameKeyboardKey('L Alt', 0xE2, width: 1.25),
    GameKeyboardKey('Space', 0x2C, width: 6.25),
    GameKeyboardKey('R Alt', 0xE6, width: 1.25),
    GameKeyboardKey('R Win', 0xE7, width: 1.25),
    GameKeyboardKey('Menu', 0x65, width: 1.25),
    GameKeyboardKey('R Ctrl', 0xE4, width: 1.25),
    GameKeyboardKey('←', 0x50, gapBefore: _gameKeyboardRightGap),
    GameKeyboardKey('↓', 0x51),
    GameKeyboardKey('→', 0x4F),
  ],
];

class GameKeyboard extends StatefulWidget {
  const GameKeyboard({
    Key? key,
    required this.controller,
    required this.onClose,
  }) : super(key: key);

  final GameKeyboardController controller;
  final VoidCallback onClose;

  @override
  State<GameKeyboard> createState() => _GameKeyboardState();
}

class _GameKeyboardState extends State<GameKeyboard> {
  final ScrollController _scrollController = ScrollController();

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target =
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    widget.controller.releaseAll();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(
      _gameKeyboardMaxHeight,
      MediaQuery.sizeOf(context).height * 0.62,
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: const Color(0xE61A1A1A),
        elevation: 12,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Keyboard',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('game-keyboard-scroll-left'),
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () =>
                          _scrollBy(-MediaQuery.sizeOf(context).width * 0.7),
                    ),
                    IconButton(
                      key: const ValueKey('game-keyboard-scroll-right'),
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () =>
                          _scrollBy(MediaQuery.sizeOf(context).width * 0.7),
                    ),
                    IconButton(
                      key: const ValueKey('game-keyboard-close'),
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        widget.controller.releaseAll();
                        widget.onClose();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyHeight = math.min(
                      _gameKeyboardMaxKeyHeight,
                      constraints.maxHeight / 6 - 2,
                    );
                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final row in gameKeyboardRows)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final key in row) ...[
                                    if (key.gapBefore > 0)
                                      SizedBox(width: key.gapBefore),
                                    _GameKeyboardKeyButton(
                                      key: ValueKey<int>(key.usbHidUsage),
                                      definition: key,
                                      controller: widget.controller,
                                      height: keyHeight,
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameKeyboardOverlay extends StatelessWidget {
  const GameKeyboardOverlay({
    Key? key,
    required this.remoteChild,
    required this.keyboard,
  }) : super(key: key);

  final Widget remoteChild;
  final Widget keyboard;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: remoteChild),
        Positioned(left: 0, right: 0, bottom: 0, child: keyboard),
      ],
    );
  }
}

class _GameKeyboardKeyButton extends StatefulWidget {
  const _GameKeyboardKeyButton({
    Key? key,
    required this.definition,
    required this.controller,
    required this.height,
  }) : super(key: key);

  final GameKeyboardKey definition;
  final GameKeyboardController controller;
  final double height;

  @override
  State<_GameKeyboardKeyButton> createState() => _GameKeyboardKeyButtonState();
}

class _GameKeyboardKeyButtonState extends State<_GameKeyboardKeyButton> {
  final Set<int> _pointers = {};

  void _press(PointerDownEvent event) {
    if (!_pointers.add(event.pointer)) {
      return;
    }
    widget.controller.press(event.pointer, widget.definition.usbHidUsage);
    setState(() {});
  }

  void _release(PointerEvent event) {
    if (!_pointers.remove(event.pointer)) {
      return;
    }
    widget.controller.release(event.pointer);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final pointer in _pointers) {
      widget.controller.release(pointer);
    }
    _pointers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _pointers.isNotEmpty;
    return SizedBox(
      width: _gameKeyboardUnit * widget.definition.width,
      height: widget.height,
      child: Semantics(
        button: true,
        label: widget.definition.label,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _press,
          onPointerUp: _release,
          onPointerCancel: _release,
          child: Container(
            margin: const EdgeInsets.all(1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1976D2) : const Color(0xFF424242),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF757575)),
            ),
            child: Text(
              widget.definition.label,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }
}
