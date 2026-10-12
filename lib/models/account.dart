import 'common.dart';
import 'user.dart';

class NotificationSettings {
  const NotificationSettings({required this.trips, required this.bookings, required this.payments, required this.news});

  final bool trips;
  final bool bookings;
  final bool payments;
  final bool news;

  NotificationSettings copyWith({bool? trips, bool? bookings, bool? payments, bool? news}) => NotificationSettings(
        trips: trips ?? this.trips,
        bookings: bookings ?? this.bookings,
        payments: payments ?? this.payments,
        news: news ?? this.news,
      );

  Json toJson() => {'trips': trips, 'bookings': bookings, 'payments': payments, 'news': news};

  factory NotificationSettings.fromJson(Json j) => NotificationSettings(
        trips: j['trips'] as bool,
        bookings: j['bookings'] as bool,
        payments: j['payments'] as bool,
        news: j['news'] as bool,
      );
}

/// Profile & settings for the signed-in account.
class Account {
  Account({required this.profile, required this.notifications, required this.nameLocked, required this.hasBilling,
      this.nameLockedReason, this.passwordChangedAt, this.memberSince});

  final UserProfile profile;
  final NotificationSettings notifications;
  final bool nameLocked;
  final String? nameLockedReason;
  final bool hasBilling;
  final DateTime? passwordChangedAt;
  final DateTime? memberSince;

  factory Account.fromJson(Json j) => Account(
        profile: UserProfile.fromJson(j['profile']),
        notifications: NotificationSettings.fromJson(j['notifications']),
        nameLocked: j['nameLocked'] as bool,
        nameLockedReason: j['nameLockedReason'],
        hasBilling: j['hasBilling'] as bool,
        passwordChangedAt: parseDate(j['passwordChangedAt']),
        memberSince: parseDate((j['profile'] as Json)['createdAt']),
      );
}

/// A signed-in device.
class DeviceSession {
  DeviceSession({required this.id, required this.deviceName, required this.signedInAt, required this.lastActiveAt,
      required this.current});

  final String id;
  final String deviceName;
  final DateTime signedInAt;
  final DateTime lastActiveAt;
  final bool current;

  factory DeviceSession.fromJson(Json j) => DeviceSession(
        id: j['id'],
        deviceName: j['deviceName'],
        signedInAt: parseDate(j['signedInAt'])!,
        lastActiveAt: parseDate(j['lastActiveAt'])!,
        current: j['current'] as bool,
      );
}
