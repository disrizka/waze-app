// lib/config/role_route_mapping.dart

/// Route publik (selalu boleh diakses, tanpa role)
const Set<String> kPublicRoutes = {'/splash', '/login', '/register', '/home'};

/// Mapping dari `page` (string dari API) → route aplikasi.
/// ISI-IN HANYA route yang SUDAH ada di onGenerateRoute kamu.
const Map<String, List<String>> kPageToRoutes = {
  // ===== HR / User =====
  'employee': ['/hr'],
  // 'user': ['/hr/user'],          // aktifkan kalau route-nya sudah ada
  'role': ['/hr/role'],

  // ===== Product =====
  'product': ['/product'],
  'product/brand': ['/brand'],
  'product/category': ['/category'],

  // ===== Purchase =====
  'purchase': ['/purchase'],
  'supplier': ['/purchase/supplier'],

  // ===== Sales =====
  'sale': ['/sales'],
  'customer': ['/sales/customer'],

  // ===== Store =====
  'store/location': ['/store'],
  'store/external': ['/store'],

  // ===== WA Business =====
  // Kalau sudah ada layar/tab khusus WABA, isi route-nya di sini.
  // Misal: 'waba': ['/waba'],
};

/// Ekspansi opsional: bila sebuah base route diizinkan, ikutkan turunannya.
/// Tujuan: UX tidak “kejepit” (mis. boleh lihat list, sekalian boleh add/detail).
const Map<String, List<String>> kPageExpansions = {
  // Product → detail product
  '/product': ['/product/detail-product'],

  // Purchase → list/add/detail/supplier-detail
  '/purchase': ['/purchase/list', '/purchase/add', '/detail-purchase'],
  '/purchase/supplier': ['/purchase/supplier/detail'],

  // Sales → add & customer
  '/sales': ['/sales/add', '/sales/customer'],
};

/// Helper: dari kumpulan `page` API yang diizinkan → set route aplikasi final.
Set<String> buildAllowedRoutesFromPages(Iterable<String> apiPages) {
  final allowed = <String>{...kPublicRoutes};

  // 1) page → route
  for (final page in apiPages) {
    final routes = kPageToRoutes[page];
    if (routes != null) allowed.addAll(routes);
  }

  // 2) ekspansi turunan (hingga stabil)
  var changed = true;
  while (changed) {
    changed = false;
    for (final base in List<String>.from(allowed)) {
      final extra = kPageExpansions[base];
      if (extra != null) {
        final before = allowed.length;
        allowed.addAll(extra);
        if (allowed.length != before) changed = true;
      }
    }
  }

  return allowed;
}
