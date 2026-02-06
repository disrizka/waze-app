part of '../../providers/notification_provider.dart';

/// =========================
/// MODEL
/// =========================
@immutable
class NotificationItem {
  final String idNotification;
  final String title;
  final String message;
  final String? imageUrl;
  final String? actionUrl;
  final String targetType;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final DateTime? readAt;

  const NotificationItem({
    required this.idNotification,
    required this.title,
    required this.message,
    required this.targetType,
    required this.isRead,
    this.imageUrl,
    this.actionUrl,
    this.createdAt,
    this.sentAt,
    this.readAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.trim().isNotEmpty) {
      return DateTime.tryParse(v.trim());
    }
    return null;
  }

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    idNotification: (j['idNotification'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    message: (j['message'] ?? '').toString(),
    imageUrl: j['imageUrl']?.toString(),
    actionUrl: j['actionUrl']?.toString(),
    targetType: (j['targetType'] ?? '').toString(),
    isRead: (j['isRead'] == true),
    createdAt: _parseDate(j['createdAt']),
    sentAt: _parseDate(j['sentAt']),
    readAt: _parseDate(j['readAt']),
  );

  NotificationItem copyWith({
    String? idNotification,
    String? title,
    String? message,
    String? imageUrl,
    String? actionUrl,
    String? targetType,
    bool? isRead,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? readAt,
  }) {
    return NotificationItem(
      idNotification: idNotification ?? this.idNotification,
      title: title ?? this.title,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      targetType: targetType ?? this.targetType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
