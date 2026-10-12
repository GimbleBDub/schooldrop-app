import 'common.dart';

class Offer {
  Offer({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    required this.vehicle,
    required this.vehiclePlate,
    required this.coverage,
    required this.capacity,
    required this.seatsAvailable,
    required this.serviceArea,
    required this.active,
    this.featured = false,
    this.companyName,
    this.driverPhone,
    this.driverPhotoUrl,
    this.morningPickupTime,
    this.pricePerTrip,
    this.pricePerMonth,
    this.pricePerTerm,
    this.adHocFare,
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final String driverId;
  final String driverName;

  /// The team / transport company the driver drives for.
  final String? companyName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final String vehicleId;
  final String vehicle;
  final String vehiclePlate;
  final String coverage; // MORNING, AFTERNOON, BOTH
  final int capacity;
  final int seatsAvailable;
  final String serviceArea;
  final String? morningPickupTime;
  final double? pricePerTrip;
  final double? pricePerMonth;
  final double? pricePerTerm;
  final double? adHocFare;
  final bool active;

  /// The driver is advertising at this school
  final bool featured;

  double? priceFor(String plan) => switch (plan) {
        'PER_TRIP' => pricePerTrip,
        'MONTHLY' => pricePerMonth,
        'TERMLY' => pricePerTerm,
        _ => null,
      };

  List<String> get plans => [
        if (pricePerMonth != null) 'MONTHLY',
        if (pricePerTerm != null) 'TERMLY',
        if (pricePerTrip != null) 'PER_TRIP',
      ];

  factory Offer.fromJson(Json j) {
    final driver = j['driver'] as Json;
    final vehicle = j['vehicle'] as Json;
    return Offer(
      id: j['id'],
      schoolId: j['schoolId'],
      schoolName: j['schoolName'],
      driverId: driver['id'],
      driverName: '${driver['firstName']} ${driver['lastName']}',
      companyName: driver['companyName'],
      driverPhone: driver['phone'],
      driverPhotoUrl: driver['profilePictureUrl'],
      vehicleId: vehicle['id'],
      vehicle: '${vehicle['colour'] != null ? '${vehicle['colour']} ' : ''}${vehicle['make']} ${vehicle['model']}',
      vehiclePlate: vehicle['plateNumber'],
      coverage: j['coverage'],
      capacity: j['capacity'],
      seatsAvailable: j['seatsAvailable'],
      serviceArea: j['serviceArea'],
      morningPickupTime: j['morningPickupTime'],
      pricePerTrip: parseMoney(j['pricePerTrip']),
      pricePerMonth: parseMoney(j['pricePerMonth']),
      pricePerTerm: parseMoney(j['pricePerTerm']),
      adHocFare: parseMoney(j['adHocFare']),
      active: j['active'] as bool,
      featured: j['featured'] as bool? ?? false,
    );
  }
}

class Booking {
  Booking({
    required this.id,
    required this.childId,
    required this.childName,
    required this.offerId,
    required this.schoolName,
    required this.driverName,
    required this.vehicle,
    required this.coverage,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.pickupAddress,
    required this.amount,
    required this.status,
    required this.parentName,
    required this.createdAt,
    this.paymentMode = 'APP',
    this.offlinePaidClaimedAt,
    this.driverPhone,
    this.termName,
    this.tripCount,
    this.notes,
    this.holdExpiresAt,
    this.cancelReason,
    this.parentPhone,
  });

  final String id;
  final String childId;
  final String childName;
  final String offerId;
  final String schoolName;
  final String driverName;
  final String? driverPhone;
  final String vehicle;
  final String coverage;
  final String plan;
  final String? termName;
  final DateTime startDate;
  final DateTime endDate;
  final int? tripCount;
  final String pickupAddress;
  final String? notes;
  final double amount;
  final String status; // PENDING_PAYMENT, ACTIVE, CANCELLED, COMPLETED, EXPIRED

  /// APP: paid through SchoolDrop. OFFLINE: paid to the driver directly, who confirms receipt.
  final String paymentMode;
  final DateTime? offlinePaidClaimedAt;
  final DateTime? holdExpiresAt;
  final String? cancelReason;
  final String parentName;
  final String? parentPhone;
  final DateTime createdAt;

  bool get awaitingPayment => status == 'PENDING_PAYMENT';
  bool get paysDriverDirectly => paymentMode == 'OFFLINE';
  bool get cancellable => status == 'PENDING_PAYMENT' || status == 'ACTIVE';

  factory Booking.fromJson(Json j) => Booking(
        id: j['id'],
        childId: j['childId'],
        childName: j['childName'],
        offerId: j['offerId'],
        schoolName: j['schoolName'],
        driverName: j['driverName'],
        driverPhone: j['driverPhone'],
        vehicle: j['vehicle'],
        coverage: j['coverage'],
        plan: j['plan'],
        termName: j['termName'],
        startDate: parseDate(j['startDate'])!,
        endDate: parseDate(j['endDate'])!,
        tripCount: j['tripCount'],
        pickupAddress: j['pickupAddress'],
        notes: j['notes'],
        amount: parseMoney(j['amount'])!,
        status: j['status'],
        paymentMode: j['paymentMode'] ?? 'APP',
        offlinePaidClaimedAt: parseDate(j['offlinePaidClaimedAt']),
        holdExpiresAt: parseDate(j['holdExpiresAt']),
        cancelReason: j['cancelReason'],
        parentName: j['parentName'],
        parentPhone: j['parentPhone'],
        createdAt: parseDate(j['createdAt'])!,
      );
}

class AdHocRequest {
  AdHocRequest({
    required this.id,
    required this.childId,
    required this.childName,
    required this.schoolName,
    required this.pickupAt,
    required this.dropoffAddress,
    required this.status,
    required this.createdAt,
    this.childGrade,
    this.notes,
    this.fare,
    this.driverName,
    this.driverPhone,
    this.vehicle,
    this.cancelReason,
  });

  final String id;
  final String childId;
  final String childName;
  final String? childGrade;
  final String schoolName;
  final DateTime pickupAt;
  final String dropoffAddress;
  final String? notes;
  final String status; // OPEN, ACCEPTED, CONFIRMED, COMPLETED, CANCELLED, EXPIRED
  final double? fare;
  final String? driverName;
  final String? driverPhone;
  final String? vehicle;
  final String? cancelReason;
  final DateTime createdAt;

  bool get active => status == 'OPEN' || status == 'ACCEPTED' || status == 'CONFIRMED';

  factory AdHocRequest.fromJson(Json j) => AdHocRequest(
        id: j['id'],
        childId: j['childId'],
        childName: j['childName'],
        childGrade: j['childGrade'],
        schoolName: j['schoolName'],
        pickupAt: parseDate(j['pickupAt'])!,
        dropoffAddress: j['dropoffAddress'],
        notes: j['notes'],
        status: j['status'],
        fare: parseMoney(j['fare']),
        driverName: j['driverName'],
        driverPhone: j['driverPhone'],
        vehicle: j['vehicle'],
        cancelReason: j['cancelReason'],
        createdAt: parseDate(j['createdAt'])!,
      );
}

class Payment {
  Payment({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.payerName,
    required this.driverName,
    required this.createdAt,
    this.bookingId,
    this.adHocRequestId,
    this.purpose = 'BOOKING',
    this.offline = false,
    this.platformFee,
    this.driverAmount,
    this.providerReference,
    this.checkoutUrl,
    this.failureReason,
    this.paidAt,
  });

  final String id;
  final String? bookingId;
  final String? adHocRequestId;
  final String purpose; // BOOKING, ADHOC, SUBSCRIPTION, ADVERT
  final bool offline;
  final double amount;
  final double? platformFee;
  final double? driverAmount;
  final String method;
  final String status; // PENDING, SUCCEEDED, FAILED, CANCELLED, REFUNDED
  final String? providerReference;
  final String? checkoutUrl;
  final String? failureReason;
  final String payerName;
  final String driverName;
  final DateTime? paidAt;
  final DateTime createdAt;

  bool get isSandbox => checkoutUrl?.contains('/payments/sandbox/') ?? false;

  factory Payment.fromJson(Json j) => Payment(
        id: j['id'],
        bookingId: j['bookingId'],
        adHocRequestId: j['adHocRequestId'],
        purpose: j['purpose'] ?? 'BOOKING',
        offline: j['offline'] as bool? ?? false,
        amount: parseMoney(j['amount'])!,
        platformFee: parseMoney(j['platformFee']),
        driverAmount: parseMoney(j['driverAmount']),
        method: j['method'],
        status: j['status'],
        providerReference: j['providerReference'],
        checkoutUrl: j['checkoutUrl'],
        failureReason: j['failureReason'],
        payerName: j['payerName'],
        driverName: j['driverName'],
        paidAt: parseDate(j['paidAt']),
        createdAt: parseDate(j['createdAt'])!,
      );
}
