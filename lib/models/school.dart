import 'common.dart';

class School {
  School({required this.id, required this.name, required this.address, required this.city, required this.status,
      this.registrationNumber, this.phone, this.email, this.statusReason, this.latitude, this.longitude});

  final String id;
  final String name;
  final String? registrationNumber;
  final String address;
  final String city;
  final String? phone;
  final String? email;
  final String status; // PENDING, VERIFIED, REJECTED, SUSPENDED
  final String? statusReason;
  final double? latitude;
  final double? longitude;

  factory School.fromJson(Json j) => School(
        id: j['id'],
        name: j['name'],
        registrationNumber: j['registrationNumber'],
        address: j['address'],
        city: j['city'],
        phone: j['phone'],
        email: j['email'],
        status: j['status'],
        statusReason: j['statusReason'],
        latitude: parseMoney(j['latitude']),
        longitude: parseMoney(j['longitude']),
      );
}

class SchoolTerm {
  SchoolTerm({required this.id, required this.name, required this.startDate, required this.endDate});

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  factory SchoolTerm.fromJson(Json j) => SchoolTerm(
      id: j['id'], name: j['name'], startDate: parseDate(j['startDate'])!, endDate: parseDate(j['endDate'])!);
}

/// A child as their school sees it.
class SchoolChild {
  SchoolChild({required this.id, required this.fullName, required this.enrollmentStatus, required this.parentName,
      this.grade, this.studentNumber, this.dateOfBirth, this.parentPhone, this.parentEmail});

  final String id;
  final String fullName;
  final String? grade;
  final String? studentNumber;
  final DateTime? dateOfBirth;
  final String enrollmentStatus;
  final String parentName;
  final String? parentPhone;
  final String? parentEmail;

  factory SchoolChild.fromJson(Json j) => SchoolChild(
        id: j['id'],
        fullName: j['fullName'],
        grade: j['grade'],
        studentNumber: j['studentNumber'],
        dateOfBirth: parseDate(j['dateOfBirth']),
        enrollmentStatus: j['enrollmentStatus'],
        parentName: j['parentName'],
        parentPhone: j['parentPhone'],
        parentEmail: j['parentEmail'],
      );
}
