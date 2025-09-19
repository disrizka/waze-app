// lib/utils/page_activation.dart
import 'package:flutter/widgets.dart';

abstract class PageActivationState<T extends StatefulWidget> extends State<T> {
  /// Dipanggil saat halaman ini jadi aktif/terlihat.
  @mustCallSuper
  void onPageActivated() {}

  /// Dipanggil saat halaman ini tidak aktif.
  @mustCallSuper
  void onPageDeactivated() {}
}
