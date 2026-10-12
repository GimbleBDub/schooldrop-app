import 'package:flutter/widgets.dart' show StringCharacters;

import 'common.dart';

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.onboardingComplete = true,
    this.householdRole,
    this.schoolRole,
    this.phone,
    this.profilePictureUrl,
    this.staffPermissions = const {},
    this.passwordChangeRequired = false,
    this.emailVerified = true,
    this.teamRole,
    this.teamName,
  });

  /// Drivers in a team / transport company: OWNER, MANAGER or DRIVER.
  final String? teamRole;
  final String? teamName;

  final String id;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? phone;
  final String role; // PARENT, DRIVER, SCHOOL, KID, ADMIN
  final String? profilePictureUrl;
  final Set<String> staffPermissions;

  /// False right after sign-up: the app shows onboarding before anything else.
  final bool onboardingComplete;

  /// Parents: OWNER, GUARDIAN or HELPER. Helpers only see trips and confirm handovers.
  final String? householdRole;

  /// School accounts: ADMIN or STAFF.
  final String? schoolRole;

  /// Staff on a temporary password: the app asks for a new one before anything else.
  final bool passwordChangeRequired;

  final bool emailVerified;

  bool get isHelper => householdRole == 'HELPER';
  bool get isFamilyOwner => householdRole == null || householdRole == 'OWNER';
  bool get isSchoolAdmin => schoolRole != 'STAFF';

  String get fullName => firstName == null ? email : '$firstName ${lastName ?? ''}'.trim();

  String get initial => (firstName ?? email).characters.first.toUpperCase();

  bool can(String permission) =>
      staffPermissions.contains('SUPER_ADMIN') || staffPermissions.contains(permission);

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: j['id'],
        firstName: j['firstName'],
        lastName: j['lastName'],
        email: j['email'],
        phone: j['phone'],
        role: j['role'],
        profilePictureUrl: j['profilePictureUrl'],
        staffPermissions: ((j['staffPermissions'] as List?) ?? const []).cast<String>().toSet(),
        onboardingComplete: j['onboardingComplete'] as bool? ?? true,
        householdRole: j['householdRole'],
        schoolRole: j['schoolRole'],
        passwordChangeRequired: j['passwordChangeRequired'] as bool? ?? false,
        emailVerified: j['emailVerified'] as bool? ?? true,
        teamRole: j['teamRole'],
        teamName: j['teamName'],
      );

  /// e.g. "Parent · Family owner", "School staff", "Staff · Finance"
  String get roleDescription => switch (role) {
        'PARENT' => switch (householdRole) {
            'GUARDIAN' => 'Parent · Guardian',
            'HELPER' => 'Family helper',
            _ => 'Parent · Family owner',
          },
        'DRIVER' => switch (teamRole) {
            'OWNER' => 'Owner · $teamName',
            'MANAGER' => 'Manager · $teamName',
            'DRIVER' => 'Driver · $teamName',
            _ => 'Driver',
          },
        'SCHOOL' => schoolRole == 'STAFF' ? 'School staff' : 'School admin',
        'KID' => 'Child',
        'ADMIN' => staffPermissions.contains('SUPER_ADMIN')
            ? 'SchoolDrop · Super admin'
            : 'SchoolDrop · ${staffPermissions.map(_permissionName).join(', ')}',
        _ => role,
      };

  /// Families' owners/guardians and drivers have billing; helpers, schools and kids don't.
  bool get hasBilling => (role == 'DRIVER' && (teamRole == null || teamRole == 'OWNER')) || (role == 'PARENT' && !isHelper);
}

String _permissionName(String p) => switch (p) {
      'VERIFIER' => 'Verification',
      'SUPPORT' => 'Support',
      'FINANCE' => 'Finance',
      'MARKETING' => 'Marketing',
      'VIEWER' => 'Read-only',
      _ => p,
    };

class NotificationItem {
  NotificationItem({required this.id, required this.type, required this.title, required this.body,
      required this.read, required this.createdAt, this.referenceId});

  final String id;
  final String type;
  final String title;
  final String body;
  final String? referenceId;
  final bool read;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Json j) => NotificationItem(
        id: j['id'],
        type: j['type'],
        title: j['title'],
        body: j['body'],
        referenceId: j['referenceId'],
        read: j['read'] as bool,
        createdAt: parseDate(j['createdAt'])!,
      );
}
