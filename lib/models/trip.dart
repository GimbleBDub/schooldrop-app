import 'common.dart';

class Trip {
  Trip({
    required this.id,
    required this.tripDate,
    required this.leg,
    required this.status,
    required this.adHoc,
    required this.schoolName,
    required this.driverName,
    required this.vehicle,
    required this.vehiclePlate,
    required this.passengers,
    this.driverPhone,
    this.driverPhotoUrl,
    this.startedAt,
    this.completedAt,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
  });

  final String id;
  final DateTime tripDate;
  final String leg; // TO_SCHOOL, FROM_SCHOOL
  final String status; // SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED
  final bool adHoc;
  final String schoolName;
  final String driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final String vehicle;
  final String vehiclePlate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationAt;
  final List<Passenger> passengers;

  bool get inProgress => status == 'IN_PROGRESS';
  bool get toSchool => leg == 'TO_SCHOOL';
  String get legLabel => adHoc ? 'Once-off pickup' : (toSchool ? 'Morning — to school' : 'Afternoon — home');

  factory Trip.fromJson(Json j) => Trip(
        id: j['id'],
        tripDate: parseDate(j['tripDate'])!,
        leg: j['leg'],
        status: j['status'],
        adHoc: j['adHoc'] as bool,
        schoolName: j['schoolName'],
        driverName: j['driverName'],
        driverPhone: j['driverPhone'],
        driverPhotoUrl: j['driverPhotoUrl'],
        vehicle: j['vehicle'],
        vehiclePlate: j['vehiclePlate'],
        startedAt: parseDate(j['startedAt']),
        completedAt: parseDate(j['completedAt']),
        lastLatitude: parseMoney(j['lastLatitude']),
        lastLongitude: parseMoney(j['lastLongitude']),
        lastLocationAt: parseDate(j['lastLocationAt']),
        passengers: parseList(j['passengers'], Passenger.fromJson),
      );
}

class Passenger {
  Passenger({
    required this.id,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.status,
    this.grade,
    this.specialNeeds,
    this.address,
    this.latitude,
    this.longitude,
    this.parentPhone,
    this.pickedUpAt,
    this.droppedOffAt,
    this.handedTo,
    this.pickupConfirmedAt,
    this.pickupConfirmedBy,
    this.dropoffConfirmedAt,
    this.dropoffConfirmedBy,
    this.disputedAt,
    this.disputeNote,
    this.kidConfirmedPickupAt,
    this.kidConfirmedDropoffAt,
  });

  final String id;
  final String childId;
  final String childName;
  final String? grade;
  final String? specialNeeds;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String parentName;
  final String? parentPhone;
  final String status; // EXPECTED, PICKED_UP, DROPPED_OFF, ABSENT

  // Driver's side
  final DateTime? pickedUpAt;
  final DateTime? droppedOffAt;
  final String? handedTo;

  // The other side: the family at home, school staff at school
  final DateTime? pickupConfirmedAt;
  final String? pickupConfirmedBy;
  final DateTime? dropoffConfirmedAt;
  final String? dropoffConfirmedBy;

  final DateTime? disputedAt;
  final String? disputeNote;
  final DateTime? kidConfirmedPickupAt;
  final DateTime? kidConfirmedDropoffAt;

  String get firstName => childName.split(' ').first;

  factory Passenger.fromJson(Json j) => Passenger(
        id: j['id'],
        childId: j['childId'],
        childName: j['childName'],
        grade: j['grade'],
        specialNeeds: j['specialNeeds'],
        address: j['address'],
        latitude: parseMoney(j['latitude']),
        longitude: parseMoney(j['longitude']),
        parentName: j['parentName'],
        parentPhone: j['parentPhone'],
        status: j['status'],
        pickedUpAt: parseDate(j['pickedUpAt']),
        droppedOffAt: parseDate(j['droppedOffAt']),
        handedTo: j['handedTo'],
        pickupConfirmedAt: parseDate(j['pickupConfirmedAt']),
        pickupConfirmedBy: j['pickupConfirmedBy'],
        dropoffConfirmedAt: parseDate(j['dropoffConfirmedAt']),
        dropoffConfirmedBy: j['dropoffConfirmedBy'],
        disputedAt: parseDate(j['disputedAt']),
        disputeNote: j['disputeNote'],
        kidConfirmedPickupAt: parseDate(j['kidConfirmedPickupAt']),
        kidConfirmedDropoffAt: parseDate(j['kidConfirmedDropoffAt']),
      );
}
