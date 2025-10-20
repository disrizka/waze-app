import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class SplashProvider with ChangeNotifier {
  // ====== FLAGS & GUARDS ======
  bool _deeplinkInProgress = false;
  bool get deeplinkInProgress => _deeplinkInProgress;

  bool _didNavigate = false;

  // ====== PENDING DEEPLINK CONTEXT ======
  Uri? _pendingDeepLink;
  String? _pendingToken;

  // ====== CONSUMED TOKENS (agar tak diproses ulang) ======
  final Map<String, DateTime> _consumedTokens = {};
  static const Duration _consumeTtl = Duration(minutes: 10);

  // ---------- Deeplink lifecycle ----------
  void beginDeepLink(Uri uri, {String? token}) {
    _pendingDeepLink = uri;
    _pendingToken = token;
    if (!_deeplinkInProgress) {
      _deeplinkInProgress = true;
      notifyListeners();
    }
  }

  void finishDeepLink() {
    _pendingDeepLink = null;
    _pendingToken = null;
    if (_deeplinkInProgress) {
      _deeplinkInProgress = false;
      notifyListeners();
    }
  }

  void abortDeepLink({bool consumeToken = true}) {
    if (consumeToken && (_pendingToken ?? '').isNotEmpty) {
      _consumedTokens[_pendingToken!] = DateTime.now();
    }
    _pendingDeepLink = null;
    _pendingToken = null;
    if (_deeplinkInProgress) {
      _deeplinkInProgress = false;
      notifyListeners();
    }
  }

  bool isTokenConsumed(String token) {
    final now = DateTime.now();
    _consumedTokens.removeWhere((_, t) => now.difference(t) > _consumeTtl);
    final hit = _consumedTokens[token];
    return hit != null && now.difference(hit) <= _consumeTtl;
  }

  // ---------- Splash guards ----------
  void resetNavigationGuards() {
    _didNavigate = false;
    _deeplinkInProgress = false;
    _pendingDeepLink = null;
    _pendingToken = null;
    notifyListeners();
  }

  // ============ AUTO LOGIN DECISION ============
  Future<void> handleAutoLogin(BuildContext context) async {
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;

    if (_deeplinkInProgress || _didNavigate) return;

    // Haluskan transisi + beri ruang init provider
    await Future.delayed(const Duration(milliseconds: 200));

    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();

    // Muat state lokal saja; tanpa cek exp atau refresh
    try {
      await auth
          .tryAutoLogin(context)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
    } catch (_) {
      // fallback: biarkan pakai state lokal yang ada
    }

    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_deeplinkInProgress || _didNavigate) return;

    final hasToken = (auth.accessToken ?? '').isNotEmpty;
    final isActivated = auth.isActivated;

    _didNavigate = true;
    final nav = Navigator.of(context, rootNavigator: true);

    if (hasToken && isActivated) {
      nav.pushNamedAndRemoveUntil('/home', (r) => false);
    } else {
      nav.pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }
}

/// Abstraksi tipis (opsional)
abstract class AuthLike {
  String? get accessToken;
  bool get isActivated;
  Future<void> tryAutoLogin(BuildContext context);
}
