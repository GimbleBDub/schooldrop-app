import 'package:schooldrop/models/booking.dart';
import 'package:schooldrop/models/common.dart';
import 'package:schooldrop/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON shapes copied from the backend's responses, so a contract change shows up here.
void main() {
  test('Offer parses nested driver/vehicle and exposes only offered plans', () {
    final offer = Offer.fromJson({
      'id': 'o1',
      'schoolId': 's1',
      'schoolName': 'Gaborone Primary',
      'driver': {'id': 'd1', 'firstName': 'Kabo', 'lastName': 'Driver', 'profilePictureUrl': null, 'phone': '+267'},
      'vehicle': {'id': 'v1', 'make': 'Toyota', 'model': 'Quantum', 'colour': 'White', 'type': 'MINIBUS',
          'plateNumber': 'B123ABC', 'seatCapacity': 14},
      'coverage': 'BOTH',
      'capacity': 2,
      'seatsAvailable': 1,
      'serviceArea': 'Phakalane',
      'morningPickupTime': '06:30',
      'pricePerTrip': 25,
      'pricePerMonth': 600.0,
      'pricePerTerm': null,
      'adHocFare': 80,
      'active': true,
    });
    expect(offer.driverName, 'Kabo Driver');
    expect(offer.vehicle, 'White Toyota Quantum');
    expect(offer.plans, ['MONTHLY', 'PER_TRIP']);
    expect(offer.priceFor('PER_TRIP'), 25.0);
  });

  test('Trip parses passengers and hides location fields when absent', () {
    final trip = Trip.fromJson({
      'id': 't1',
      'tripDate': '2026-10-07',
      'leg': 'FROM_SCHOOL',
      'status': 'IN_PROGRESS',
      'adHoc': false,
      'schoolId': 's1',
      'schoolName': 'Gaborone Primary',
      'driverName': 'Kabo Driver',
      'driverPhone': null,
      'driverPhotoUrl': null,
      'vehicle': 'White Toyota Quantum (B123ABC)',
      'vehiclePlate': 'B123ABC',
      'startedAt': '2026-10-07T12:00:00Z',
      'completedAt': null,
      'lastLatitude': -24.6,
      'lastLongitude': 25.9,
      'lastLocationAt': '2026-10-07T12:05:00Z',
      'passengers': [
        {'id': 'p1', 'childId': 'c1', 'childName': 'Neo Kgosi', 'grade': 'Std 3', 'specialNeeds': null,
          'address': 'Plot 5', 'latitude': null, 'longitude': null, 'parentName': 'Ama', 'parentPhone': null,
          'status': 'PICKED_UP', 'pickedUpAt': '2026-10-07T12:03:00Z', 'droppedOffAt': null, 'handedTo': null,
          'pickupConfirmedAt': '2026-10-07T12:02:00Z', 'pickupConfirmedBy': 'Kefilwe Dube',
          'dropoffConfirmedAt': null, 'dropoffConfirmedBy': null, 'disputedAt': null, 'disputeNote': null,
          'kidConfirmedPickupAt': null, 'kidConfirmedDropoffAt': null},
      ],
    });
    expect(trip.inProgress, isTrue);
    expect(trip.toSchool, isFalse);
    expect(trip.passengers.single.pickupConfirmedBy, 'Kefilwe Dube');
    expect(trip.passengers.single.dropoffConfirmedAt, isNull);
    expect(trip.lastLatitude, -24.6);
  });

  test('label humanises backend enums', () {
    expect(label('PENDING_PAYMENT'), 'Pending payment');
    expect(label(null), '');
  });
}
