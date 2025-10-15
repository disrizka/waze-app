// lib/deeplink_service.dart
import 'dart:async';
import 'dart:convert'; // ⬅️ for jsonDecode (token fallback)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/hr_provider.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/screens/register/link/link_register_stepper_wrapper.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  bool _initialTried = false;
  bool _inited = false; // cegah init ganda

  // Dedup & debounce
  Uri? _lastUri;
  String? _lastToken;
  DateTime _lastHandledAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _debounce = const Duration(milliseconds: 900);

  // Cegah re-entrancy nav
  bool _navLock = false;

  // Hard timeout untuk seluruh siklus route
  final Duration _routeHardTimeout = const Duration(seconds: 4);

  void init() {
    if (_inited) {
      if (kDebugMode) debugPrint('[DeepLink] init skipped (already inited)');
      return;
    }
    _inited = true;

    _handleInitialLink(); // saat cold start
    _listenLinkStream(); // saat app hidup lalu ada link baru
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _inited = false;
  }

  Future<void> _handleInitialLink() async {
    if (_initialTried) return;
    _initialTried = true;

    try {
      final Uri? uri = await _appLinks.getInitialLink();
      if (kDebugMode) debugPrint('[DeepLink] initial uri: $uri');
      if (uri != null) {
        // Tidak di-await (biar tidak blokir start up), aman karena ada watchdog di _routeFromUri
        unawaited(_routeFromUri(uri, source: 'initial'));
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DeepLink] initial link error: $e');
        debugPrint('$st');
      }
    }
  }

  void _listenLinkStream() {
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (Uri? uri) async {
        if (uri == null) return;
        if (kDebugMode) debugPrint('[DeepLink] stream uri: $uri');

        final now = DateTime.now();
        final tokenFromUri = _extractTokenFromUri(uri);
        if (_lastToken == tokenFromUri &&
            now.difference(_lastHandledAt) < _debounce) {
          if (kDebugMode)
            debugPrint('[DeepLink] skipped (debounce same token)');
          return;
        }

        unawaited(_routeFromUri(uri, source: 'stream'));
      },
      onError: (e, st) {
        if (kDebugMode) {
          debugPrint('[DeepLink] stream error: $e');
          debugPrint('$st');
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _routeFromUri(Uri uri, {required String source}) async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;

    final url = uri.toString();
    final token = _extractTokenFromUri(uri);

    if (kDebugMode) {
      debugPrint('[DeepLink] source=$source url=$url');
      debugPrint('[DeepLink] extracted token: $token');
    }
    if (token.isEmpty) {
      _showSnack(ctx, 'Invalid invite link');
      return;
    }

    // === Dedup + debounce ===
    final now = DateTime.now();
    if (_lastToken == token && now.difference(_lastHandledAt) < _debounce) {
      if (kDebugMode) debugPrint('[DeepLink] skipped (duplicate token)');
      return;
    }
    if (_navLock) {
      if (kDebugMode) debugPrint('[DeepLink] nav locked; skip');
      return;
    }

    // Tandai jejak terlebih dulu
    _navLock = true;
    _lastHandledAt = now;
    _lastUri = uri;
    _lastToken = token;

    // Koordinasi dengan Splash: flag aktif
    final splash = ctx.read<SplashProvider>();
    splash.beginDeepLink(uri, token: token);

    // === WATCHDOG: matikan flag jika melebihi hard timeout ===
    bool finished = false;
    Timer? watchdog;
    watchdog = Timer(_routeHardTimeout, () {
      if (finished) return;
      if (kDebugMode) {
        debugPrint(
          '[DeepLink] WATCHDOG fired after ${_routeHardTimeout.inMilliseconds}ms',
        );
      }
      _navLock = false;
      splash.abortDeepLink(consumeToken: false);
      // NB: tidak push apa-apa di watchdog; Splash lanjut sesuai auto-login
    });

    try {
      // Ambil preview dari server — tambahkan TIMEOUT ketat
      final prov = ctx.read<HrProvider>();
      final preview = await prov
          .getInviteData(ctx, token: token)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      if (preview == null) {
        final err = prov.lastError ?? 'Failed to open invite (timeout)';
        if (kDebugMode) debugPrint('[DeepLink] ❌ $err');
        _showSnack(ctx, err);

        // token invalid/expired → konsumsi supaya tidak di-fetch ulang
        splash.abortDeepLink(consumeToken: true);
        return; // finally di bawah tetap jalan
      }

      if (kDebugMode) {
        debugPrint(
          '[DeepLink] ✅ invite -> email=${preview.email}, biz=${preview.businessName}, role=${preview.roleName}, isAccountExists=${preview.isAccountExists}',
        );
      }

      // ======== TIGA KONDISI (pakai isAccountExists dari backend) ========
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = (prefs.getString('email') ?? '').trim().toLowerCase();

      // Ambil status login & token yang valid:
      String? tokenFromAuth;
      try {
        final auth = ctx.read<AuthProvider>();
        tokenFromAuth = auth.accessToken; // getter dari AuthProvider
      } catch (_) {}

      // Fallback: prefs 'accessToken' (camelCase)
      String? tokenFromPrefs = prefs.getString('accessToken');

      // Fallback terakhir: prefs 'token' berisi JSON → ambil access_token
      if ((tokenFromAuth == null || tokenFromAuth.isEmpty) &&
          (tokenFromPrefs == null || tokenFromPrefs.isEmpty)) {
        try {
          final tokenJsonStr = prefs.getString('token');
          if (tokenJsonStr != null && tokenJsonStr.isNotEmpty) {
            final map = jsonDecode(tokenJsonStr) as Map<String, dynamic>;
            tokenFromPrefs = (map['access_token'] ?? '').toString();
          }
        } catch (_) {}
      }

      final String effectiveAccessToken = (tokenFromAuth?.isNotEmpty == true)
          ? tokenFromAuth!
          : (tokenFromPrefs ?? '');
      final bool loggedIn = effectiveAccessToken.isNotEmpty;

      final inviteEmail = preview.email.trim().toLowerCase();
      final emailMatch = savedEmail.isNotEmpty && savedEmail == inviteEmail;

      // 🔎 Debug prints
      if (kDebugMode) {
        debugPrint('[DeepLink] Saved email (prefs): $savedEmail');
        debugPrint('[DeepLink] Invite email (from link): $inviteEmail');
        debugPrint('[DeepLink] Email match? $emailMatch');
        debugPrint(
          '[DeepLink] Access token (from Auth): ${tokenFromAuth?.isNotEmpty == true}',
        );
        debugPrint(
          '[DeepLink] Access token (from Prefs): ${tokenFromPrefs?.isNotEmpty == true}',
        );
        debugPrint('[DeepLink] Logged in? $loggedIn');
      }

      if (!preview.isAccountExists) {
        // === CASE #1: Akun belum ada -> flow registrasi penuh (seperti sekarang)
        if (kDebugMode)
          debugPrint(
            '[DeepLink] Case #1: isAccountExists=false → full LinkRegister flow',
          );

        final currentName = ModalRoute.of(
          appNavigatorKey.currentContext!,
        )?.settings.name;
        if (currentName == 'link-register') {
          if (kDebugMode)
            debugPrint('[DeepLink] already on LinkRegister; ignore push');
          splash.finishDeepLink();
          return;
        }

        final rootNav = Navigator.of(ctx, rootNavigator: true);
        await Future.microtask(() {});
        if (kDebugMode)
          debugPrint('[DeepLink] → pushing LinkRegister (full flow)');

        await rootNav.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'link-register'),
            maintainState: true,
            builder: (_) => LinkRegisterStepperWrapper(
              inviteEmail: preview.email,
              inviteToken: (preview.token.isNotEmpty) ? preview.token : token,
              businessName: preview.businessName,
              businessLogo: (preview.businessLogo.isNotEmpty)
                  ? preview.businessLogo
                  : 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=200',
              inviteRoleName: preview.roleName,
              loginOnlyFlow: false, // full
            ),
          ),
        );
        if (kDebugMode)
          debugPrint('[DeepLink] ← popped LinkRegister (case #1)');
        return;
      } else {
        // isAccountExists == true
        if (loggedIn && emailMatch) {
          // === CASE #3: Sudah login & email cocok → ke /home dulu, lalu dialog accept (tanpa body)
          if (kDebugMode) {
            debugPrint(
              '[DeepLink] Case #3: logged-in + email match → go /home then confirm & accept (no body)',
            );
          }

          // Pastikan splash tak nge-hold
          splash.finishDeepLink();

          // 1) Jika bukan di /home, navigate ke /home terlebih dulu
          final currName = ModalRoute.of(
            appNavigatorKey.currentContext!,
          )?.settings.name;
          if (currName != '/home' && currName != 'home') {
            final rootNav = Navigator.of(ctx, rootNavigator: true);
            rootNav.pushNamedAndRemoveUntil('/home', (r) => false);
          }

          // 2) Tampilkan dialog di atas /home (di frame berikut agar context valid)
          await Future.microtask(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final hostCtx = appNavigatorKey.currentContext ?? ctx;

            final accepted = await _confirmAcceptInviteDialog(
              hostCtx,
              businessName: preview.businessName,
              roleName: preview.roleName,
            );

            if (accepted == true) {
              final ok = await hostCtx.read<HrProvider>().acceptInviteLoggedIn(
                context: hostCtx,
                token: (preview.token.isNotEmpty) ? preview.token : token,
              );
              if (ok) {
                // ✅ immediately refresh latest user profile
                await hostCtx.read<AuthProvider>().refreshCurrentUser(hostCtx);
                // 🔁 then reload app flow from splash
                final navNow = Navigator.of(hostCtx, rootNavigator: true);
                final sp = appNavigatorKey.currentContext
                    ?.read<SplashProvider>();
                sp?.resetNavigationGuards();
                sp?.abortDeepLink();
                navNow.pushNamedAndRemoveUntil('/splash', (r) => false);
              }
            }
          });

          return; // selesai, tidak push LinkRegister
        }

        // === CASE #2: Akun ada tapi belum login (atau login dg email berbeda) → LoginOnly flow
        if (kDebugMode) {
          debugPrint(
            '[DeepLink] Case #2: isAccountExists=true but not logged-in (or email mismatch) → LinkRegister (Welcome+Login)',
          );
        }

        final currentName = ModalRoute.of(
          appNavigatorKey.currentContext!,
        )?.settings.name;
        if (currentName == 'link-register') {
          if (kDebugMode)
            debugPrint('[DeepLink] already on LinkRegister; ignore push');
          splash.finishDeepLink();
          return;
        }

        final rootNav = Navigator.of(ctx, rootNavigator: true);
        await Future.microtask(() {});
        if (kDebugMode)
          debugPrint('[DeepLink] → pushing LinkRegister (loginOnlyFlow=true)');

        await rootNav.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'link-register'),
            maintainState: true,
            builder: (_) => LinkRegisterStepperWrapper(
              inviteEmail: preview.email,
              inviteToken: (preview.token.isNotEmpty) ? preview.token : token,
              businessName: preview.businessName,
              businessLogo: (preview.businessLogo.isNotEmpty)
                  ? preview.businessLogo
                  : 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=200',
              inviteRoleName: preview.roleName,
              loginOnlyFlow: true, // hanya Welcome + Login
            ),
          ),
        );
        if (kDebugMode)
          debugPrint('[DeepLink] ← popped LinkRegister (case #2)');
        return;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DeepLink] route error: $e');
        debugPrint('$st');
      }
      _showSnack(ctx, 'Failed to open invite');
      splash.abortDeepLink(consumeToken: false);
    } finally {
      finished = true;
      watchdog?.cancel();
      watchdog = null;

      // beri sedikit jeda agar event lain tidak langsung menimpa
      await Future.delayed(const Duration(milliseconds: 120));
      _navLock = false;

      // Matikan flag deeplink dengan cara yang aman
      if (splash.deeplinkInProgress) {
        splash.finishDeepLink();
      }
      if (kDebugMode) {
        debugPrint(
          '[DeepLink] flags cleared (navLock=false, deeplink=${splash.deeplinkInProgress})',
        );
      }
    }
  }

  String _extractTokenFromUri(Uri uri) {
    // Dukung pola `waveup://hr/invite/<token>` (host=hr) dan fallback
    // 1) Scheme host = 'hr' -> pathSegments = ['invite', '<token>']
    if (uri.host == 'hr' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'invite') {
      return uri.pathSegments[1];
    }

    // 2) Pola lama: pathSegments = ['hr', 'invite', '<token>']
    final segs = uri.pathSegments;
    if (segs.length >= 3 && segs[0] == 'hr' && segs[1] == 'invite') {
      return segs[2];
    }

    // 3) Query param biasa
    final qp = uri.queryParameters;
    final fromQuery = qp['token'] ?? qp['code'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

    // 4) Fallback=https://.../hr/invite/<token>
    final fb = qp['fallback'];
    if (fb != null && fb.isNotEmpty) {
      try {
        final fbu = Uri.parse(fb);
        final fsegs = fbu.pathSegments;
        if (fsegs.length >= 3 && fsegs[0] == 'hr' && fsegs[1] == 'invite') {
          return fsegs[2];
        }
        final fbq = fbu.queryParameters['token'] ?? fbu.queryParameters['code'];
        if (fbq != null && fbq.isNotEmpty) return fbq;
      } catch (_) {}
    }

    return '';
  }

  Future<bool?> _confirmAcceptInviteDialog(
    BuildContext ctx, {
    required String businessName,
    String? businessLogo,
    String? roleName,
    String? email,
  }) {
    final theme = Theme.of(ctx);
    return showDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      builder: (c) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    'Accept Invitation?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle (with bold role name)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(
                          text: 'You have been invited to join as ',
                        ),
                        if (roleName != null && roleName.isNotEmpty)
                          TextSpan(
                            text: roleName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        const TextSpan(text: ' in '),
                        TextSpan(
                          text: businessName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Business info card
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      color: const Color(0xFFFBFDFF),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Business logo
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              (businessLogo != null && businessLogo.isNotEmpty)
                              ? Image.network(
                                  businessLogo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.apartment_rounded,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.apartment_rounded,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Business name
                              Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Role (optional)
                              if (roleName != null && roleName.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_rounded,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        roleName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF1F2937),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),

                              // Email (optional)
                              if (email != null && email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Info note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'This invitation applies only to your current account.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Maybe Later'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(c).pop(true),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(msg)));
  }
}
