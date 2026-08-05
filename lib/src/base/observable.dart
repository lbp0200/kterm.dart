mixin Observable {
  final _listeners = <void Function()>{};

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    // Iterate over a snapshot so listeners may safely add/remove listeners
    // during notification (mirrors Flutter's ChangeNotifier semantics).
    for (var listener in List.of(_listeners)) {
      listener();
    }
  }
}
