import 'package:flutter/widgets.dart';

class AppLifecycleNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleState _state = AppLifecycleState.resumed;
  bool _attached = false;

  AppLifecycleState get state => _state;
  bool get isResumed => _state == AppLifecycleState.resumed;

  void attach() {
    if (_attached) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == _state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
