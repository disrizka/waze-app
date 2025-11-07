import 'package:flutter/foundation.dart';

class SafeChangeNotifier extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @protected
  @override
  void notifyListeners() {
    if (_isDisposed) return; // menelan notifikasi setelah dispose
    super.notifyListeners();
  }
}
