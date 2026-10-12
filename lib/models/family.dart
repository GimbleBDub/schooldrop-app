import 'common.dart';

class Invite {
  Invite({required this.id, required this.role, required this.expiresAt, this.inviteeName, this.code});

  final String id;
  final String role;
  final String? inviteeName;

  /// Only present right after creating the invite.
  final String? code;
  final DateTime expiresAt;

  factory Invite.fromJson(Json j) => Invite(
        id: j['id'],
        role: j['role'],
        inviteeName: j['inviteeName'],
        code: j['code'],
        expiresAt: parseDate(j['expiresAt'])!,
      );
}

class Household {
  Household({required this.id, required this.name, required this.myRole, required this.members, required this.invites});

  final String id;
  final String name;
  final String myRole; // OWNER, GUARDIAN, HELPER
  final List<HouseholdMember> members;
  final List<Invite> invites;

  factory Household.fromJson(Json j) => Household(
        id: j['id'],
        name: j['name'],
        myRole: j['myRole'],
        members: parseList(j['members'], HouseholdMember.fromJson),
        invites: parseList(j['pendingInvites'], Invite.fromJson),
      );
}

class HouseholdMember {
  HouseholdMember({required this.id, required this.name, required this.role, required this.you, this.phone});

  final String id;
  final String name;
  final String? phone;
  final String role;
  final bool you;

  factory HouseholdMember.fromJson(Json j) =>
      HouseholdMember(id: j['id'], name: j['name'], phone: j['phone'], role: j['role'], you: j['you'] as bool);
}

class SchoolStaffList {
  SchoolStaffList({required this.myRole, required this.staff, required this.invites});

  final String myRole; // ADMIN, STAFF
  final List<StaffMember> staff;
  final List<Invite> invites;

  factory SchoolStaffList.fromJson(Json j) => SchoolStaffList(
        myRole: j['myRole'],
        staff: parseList(j['staff'], StaffMember.fromJson),
        invites: parseList(j['pendingInvites'], Invite.fromJson),
      );
}

class StaffMember {
  StaffMember({required this.id, required this.name, required this.email, required this.role, required this.you,
      this.phone, this.title});

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? title;
  final bool you;

  factory StaffMember.fromJson(Json j) => StaffMember(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        phone: j['phone'],
        role: j['role'],
        title: j['title'],
        you: j['you'] as bool,
      );
}
