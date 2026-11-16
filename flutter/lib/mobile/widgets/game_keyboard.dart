typedef GameKeyboardEventSender = void Function(int usbHidUsage, bool down);

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
      sendEvent(usbHidUsage, true);
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
      sendEvent(usage, false);
    } else {
      _usageRefCounts[usage] = refCount - 1;
    }
  }

  void releaseAll() {
    final usages = _usageRefCounts.keys.toList();
    _pointerUsages.clear();
    _usageRefCounts.clear();
    for (final usage in usages) {
      sendEvent(usage, false);
    }
  }
}
