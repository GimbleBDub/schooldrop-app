import 'common.dart';

class Dashboard {
  Dashboard(this.raw);

  final Json raw;

  int count(String key) => (raw[key] as num).toInt();
  double money(String key) => (raw[key] as num).toDouble();

  factory Dashboard.fromJson(Json j) => Dashboard(j);
}

class AdminUser {
  AdminUser({required this.id, required this.fullName, required this.email, required this.role,
      required this.enabled, required this.staffPermissions, this.phone, this.createdAt,
      this.passwordChangeRequired = false, this.temporaryPassword});

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final bool enabled;
  final Set<String> staffPermissions;
  final DateTime? createdAt;

  /// Staff still on a temporary password.
  final bool passwordChangeRequired;

  /// Only right after creating / resetting a staff account: shown once.
  final String? temporaryPassword;

  factory AdminUser.fromJson(Json j) => AdminUser(
        id: j['id'],
        fullName: j['fullName'],
        email: j['email'],
        phone: j['phone'],
        role: j['role'],
        enabled: j['enabled'] as bool,
        staffPermissions: ((j['staffPermissions'] as List?) ?? const []).cast<String>().toSet(),
        createdAt: parseDate(j['createdAt']),
        passwordChangeRequired: j['passwordChangeRequired'] as bool? ?? false,
        temporaryPassword: j['temporaryPassword'],
      );
}

class Incident {
  Incident({required this.id, required this.type, required this.status, required this.description,
      required this.reporterName, required this.reporterRole, required this.createdAt, this.reporterPhone,
      this.tripId, this.driverName, this.resolution, this.latitude, this.longitude});

  final String id;
  final String type; // SOS, SAFETY_CONCERN, COMPLAINT, OTHER
  final String status; // OPEN, IN_PROGRESS, RESOLVED
  final String description;
  final String reporterName;
  final String reporterRole;
  final String? reporterPhone;
  final String? tripId;
  final String? driverName;
  final String? resolution;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  factory Incident.fromJson(Json j) => Incident(
        id: j['id'],
        type: j['type'],
        status: j['status'],
        description: j['description'],
        reporterName: j['reporterName'],
        reporterRole: j['reporterRole'],
        reporterPhone: j['reporterPhone'],
        tripId: j['tripId'],
        driverName: j['driverName'],
        resolution: j['resolution'],
        latitude: parseMoney(j['latitude']),
        longitude: parseMoney(j['longitude']),
        createdAt: parseDate(j['createdAt'])!,
      );
}

class AuditEntry {
  AuditEntry({required this.actorName, required this.action, required this.targetType, required this.createdAt,
      this.targetId, this.details});

  final String actorName;
  final String action;
  final String targetType;
  final String? targetId;
  final String? details;
  final DateTime createdAt;

  factory AuditEntry.fromJson(Json j) => AuditEntry(
        actorName: j['actorName'],
        action: j['action'],
        targetType: j['targetType'],
        targetId: j['targetId'],
        details: j['details'],
        createdAt: parseDate(j['createdAt'])!,
      );
}
