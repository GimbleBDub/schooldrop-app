import 'common.dart';

class Child {
  Child({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.devicePaired,
    this.dateOfBirth,
    this.grade,
    this.studentNumber,
    this.specialNeeds,
    this.schoolId,
    this.schoolName,
    this.enrollmentStatus,
    this.enrollmentNote,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? grade;
  final String? studentNumber;
  final String? specialNeeds;
  final String? schoolId;
  final String? schoolName;
  final String? enrollmentStatus; // PENDING, CONFIRMED, REJECTED
  final String? enrollmentNote;
  final bool devicePaired;

  String get fullName => '$firstName $lastName';
  bool get canBook => enrollmentStatus == 'CONFIRMED';

  factory Child.fromJson(Json j) => Child(
        id: j['id'],
        firstName: j['firstName'],
        lastName: j['lastName'],
        dateOfBirth: parseDate(j['dateOfBirth']),
        grade: j['grade'],
        studentNumber: j['studentNumber'],
        specialNeeds: j['specialNeeds'],
        schoolId: j['schoolId'],
        schoolName: j['schoolName'],
        enrollmentStatus: j['enrollmentStatus'],
        enrollmentNote: j['enrollmentNote'],
        devicePaired: j['devicePaired'] as bool,
      );
}

class PairingCode {
  PairingCode(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;

  factory PairingCode.fromJson(Json j) => PairingCode(j['code'], parseDate(j['expiresAt'])!);
}
