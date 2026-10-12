import 'common.dart';
import 'school.dart';

class Vehicle {
  Vehicle({required this.id, required this.make, required this.model, required this.plateNumber, required this.type,
      required this.seatCapacity, required this.active, required this.verified, this.year, this.colour,
      this.roadworthyExpiry, this.insuranceExpiry});

  final String id;
  final String make;
  final String model;
  final int? year;
  final String? colour;
  final String plateNumber;
  final String type;
  final int seatCapacity;
  final DateTime? roadworthyExpiry;
  final DateTime? insuranceExpiry;
  final bool active;
  final bool verified;

  String get displayName => '${colour != null ? '$colour ' : ''}$make $model ($plateNumber)';

  factory Vehicle.fromJson(Json j) => Vehicle(
        id: j['id'],
        make: j['make'],
        model: j['model'],
        year: j['year'],
        colour: j['colour'],
        plateNumber: j['plateNumber'],
        type: j['type'],
        seatCapacity: j['seatCapacity'],
        roadworthyExpiry: parseDate(j['roadworthyExpiry']),
        insuranceExpiry: parseDate(j['insuranceExpiry']),
        active: j['active'] as bool,
        verified: j['verified'] as bool,
      );
}

class DriverDocument {
  DriverDocument({required this.id, required this.type, required this.status, required this.contentType,
      required this.uploadedAt, this.vehicleId, this.vehiclePlate, this.referenceNumber, this.issuedOn,
      this.expiresOn, this.reviewNote, this.originalFilename});

  final String id;
  final String type;
  final String? vehicleId;
  final String? vehiclePlate;
  final String status; // PENDING, APPROVED, REJECTED, EXPIRED
  final String? referenceNumber;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final String? reviewNote;
  final String? originalFilename;
  final String contentType;
  final DateTime uploadedAt;

  bool get isImage => contentType.startsWith('image/');

  factory DriverDocument.fromJson(Json j) => DriverDocument(
        id: j['id'],
        type: j['type'],
        vehicleId: j['vehicleId'],
        vehiclePlate: j['vehiclePlate'],
        status: j['status'],
        referenceNumber: j['referenceNumber'],
        issuedOn: parseDate(j['issuedOn']),
        expiresOn: parseDate(j['expiresOn']),
        reviewNote: j['reviewNote'],
        originalFilename: j['originalFilename'],
        contentType: j['contentType'],
        uploadedAt: parseDate(j['uploadedAt'])!,
      );
}

class DriverProfile {
  DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.status,
    required this.acceptsAdHoc,
    required this.schools,
    required this.vehicles,
    required this.documents,
    required this.missingRequirements,
    this.phone,
    this.statusReason,
    this.omangNumber,
    this.licenceNumber,
    this.licenceCode,
    this.licenceExpiry,
    this.dateOfBirth,
    this.homeArea,
    this.payoutMethod,
    this.payoutAccount,
    this.submittedAt,
    this.team,
    this.drives = true,
    this.managesRoutes = true,
    this.ownsBusiness = true,
  });

  final String id;
  final String userId;

  /// The team / transport company, or null when driving on their own.
  final TeamCard? team;

  /// False for owners / managers who only run the business (no licence needed, never on a route).
  final bool drives;

  /// Sets up vehicles and routes: solo drivers, team owners and managers.
  final bool managesRoutes;

  /// Payouts, listing fee, adverts, billing: solo drivers and team owners.
  final bool ownsBusiness;

  bool get inTeam => team != null;
  final String fullName;
  final String email;
  final String? phone;
  final String status; // PENDING_DOCUMENTS, UNDER_REVIEW, APPROVED, REJECTED, SUSPENDED
  final String? statusReason;
  final String? omangNumber;
  final String? licenceNumber;
  final String? licenceCode;
  final DateTime? licenceExpiry;
  final DateTime? dateOfBirth;
  final String? homeArea;
  final bool acceptsAdHoc;
  final String? payoutMethod;
  final String? payoutAccount;
  final List<School> schools;
  final List<Vehicle> vehicles;
  final List<DriverDocument> documents;
  final List<String> missingRequirements;
  final DateTime? submittedAt;

  bool get isApproved => status == 'APPROVED';
  bool get canSubmit => status == 'PENDING_DOCUMENTS' || status == 'REJECTED';

  factory DriverProfile.fromJson(Json j) => DriverProfile(
        id: j['id'],
        userId: j['userId'],
        fullName: j['fullName'],
        email: j['email'],
        phone: j['phone'],
        status: j['status'],
        statusReason: j['statusReason'],
        omangNumber: j['omangNumber'],
        licenceNumber: j['licenceNumber'],
        licenceCode: j['licenceCode'],
        licenceExpiry: parseDate(j['licenceExpiry']),
        dateOfBirth: parseDate(j['dateOfBirth']),
        homeArea: j['homeArea'],
        acceptsAdHoc: j['acceptsAdHoc'] as bool,
        payoutMethod: j['payoutMethod'],
        payoutAccount: j['payoutAccount'],
        schools: parseList(j['schools'], School.fromJson),
        vehicles: parseList(j['vehicles'], Vehicle.fromJson),
        documents: parseList(j['documents'], DriverDocument.fromJson),
        missingRequirements: ((j['missingRequirements'] as List?) ?? const []).cast<String>(),
        submittedAt: parseDate(j['submittedAt']),
        team: j['team'] == null ? null : TeamCard.fromJson(j['team']),
        drives: j['drives'] as bool? ?? true,
        managesRoutes: j['managesRoutes'] as bool? ?? true,
        ownsBusiness: j['ownsBusiness'] as bool? ?? true,
      );
}

class TeamCard {
  TeamCard({required this.id, required this.name, required this.kind, required this.role, required this.ownerName});

  final String id;
  final String name;
  final String kind; // TEAM, COMPANY
  final String role; // OWNER, MANAGER, DRIVER
  final String ownerName;

  factory TeamCard.fromJson(Json j) =>
      TeamCard(id: j['id'], name: j['name'], kind: j['kind'], role: j['role'], ownerName: j['ownerName']);
}

class TeamMember {
  TeamMember({required this.driverId, required this.name, required this.role, required this.drives, required this.status,
      required this.you, required this.activeRoutes, this.phone});

  final String driverId;
  final String name;
  final String? phone;
  final String role;
  final bool drives;
  final String status;
  final bool you;
  final int activeRoutes;

  bool get canDrive => drives && status == 'APPROVED';

  factory TeamMember.fromJson(Json j) => TeamMember(
        driverId: j['driverId'],
        name: j['name'],
        phone: j['phone'],
        role: j['role'],
        drives: j['drives'] as bool,
        status: j['status'],
        you: j['you'] as bool,
        activeRoutes: (j['activeRoutes'] as num).toInt(),
      );
}

class Team {
  Team({required this.id, required this.name, required this.kind, required this.myRole, required this.ownerName,
      required this.ownerStatus, required this.members, required this.invites, required this.vehicles,
      required this.drivers, required this.monthlyFee, this.registrationNumber, this.listedUntil});

  final String id;
  final String name;
  final String kind;
  final String? registrationNumber;
  final String myRole;
  final String ownerName;
  final String ownerStatus;
  final List<TeamMember> members;
  final List<TeamInvite> invites;
  final int vehicles;
  final int drivers;
  final double monthlyFee;
  final DateTime? listedUntil;

  bool get iManage => myRole != 'DRIVER';
  bool get iOwn => myRole == 'OWNER';

  factory Team.fromJson(Json j) => Team(
        id: j['id'],
        name: j['name'],
        kind: j['kind'],
        registrationNumber: j['registrationNumber'],
        myRole: j['myRole'],
        ownerName: j['ownerName'],
        ownerStatus: j['ownerStatus'],
        members: parseList(j['members'], TeamMember.fromJson),
        invites: parseList(j['invites'], TeamInvite.fromJson),
        vehicles: (j['vehicles'] as num).toInt(),
        drivers: (j['drivers'] as num).toInt(),
        monthlyFee: parseMoney(j['monthlyFee']) ?? 0,
        listedUntil: parseDate(j['listedUntil']),
      );
}

class TeamInvite {
  TeamInvite({required this.id, required this.role, required this.expiresAt, this.inviteeName, this.code});

  final String id;
  final String role;
  final String? inviteeName;
  final String? code;
  final DateTime expiresAt;

  factory TeamInvite.fromJson(Json j) => TeamInvite(
        id: j['id'],
        role: j['role'],
        inviteeName: j['inviteeName'],
        code: j['code'],
        expiresAt: parseDate(j['expiresAt'])!,
      );
}

class DriverSummary {
  DriverSummary({required this.id, required this.fullName, required this.email, required this.status,
      required this.createdAt, this.phone, this.submittedAt, this.team});

  /// e.g. "Owner · Safe Rides (company)"
  final String? team;

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String status;
  final DateTime? submittedAt;
  final DateTime createdAt;

  factory DriverSummary.fromJson(Json j) => DriverSummary(
        id: j['id'],
        fullName: j['fullName'],
        email: j['email'],
        phone: j['phone'],
        status: j['status'],
        submittedAt: parseDate(j['submittedAt']),
        createdAt: parseDate(j['createdAt'])!,
        team: j['team'],
      );
}

class Earnings {
  Earnings({required this.available, required this.upcoming, required this.recent, required this.payouts});

  final double available;
  final double upcoming;
  final List<EarningLine> recent;
  final List<Payout> payouts;

  factory Earnings.fromJson(Json j) => Earnings(
        available: parseMoney(j['availableBalance'])!,
        upcoming: parseMoney(j['upcomingBalance'])!,
        recent: parseList(j['recent'], EarningLine.fromJson),
        payouts: parseList(j['payouts'], Payout.fromJson),
      );
}

class EarningLine {
  EarningLine({required this.description, required this.amount, required this.status, required this.paidOut,
      this.availableOn});

  final String description;
  final double amount;
  final String status;
  final DateTime? availableOn;
  final bool paidOut;

  factory EarningLine.fromJson(Json j) => EarningLine(
        description: j['description'],
        amount: parseMoney(j['amount'])!,
        status: j['status'],
        availableOn: parseDate(j['availableOn']),
        paidOut: j['paidOut'] as bool,
      );
}

class Payout {
  Payout({required this.id, required this.driverName, required this.amount, required this.method,
      required this.account, required this.status, required this.createdAt, this.reference, this.failureReason});

  final String id;
  final String driverName;
  final double amount;
  final String method;
  final String account;
  final String status;
  final String? reference;
  final String? failureReason;
  final DateTime createdAt;

  factory Payout.fromJson(Json j) => Payout(
        id: j['id'],
        driverName: j['driverName'],
        amount: parseMoney(j['amount'])!,
        method: j['method'],
        account: j['account'],
        status: j['status'],
        reference: j['reference'],
        failureReason: j['failureReason'],
        createdAt: parseDate(j['createdAt'])!,
      );
}
