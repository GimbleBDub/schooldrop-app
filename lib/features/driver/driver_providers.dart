import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../models/booking.dart';
import '../../models/driver.dart';
import '../../models/trip.dart';

final driverProfileProvider = FutureProvider.autoDispose<DriverProfile>((ref) => ref.watch(driverApiProvider).profile());

final driverTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(driverApiProvider).trips());

final driverOffersProvider = FutureProvider.autoDispose<List<Offer>>((ref) => ref.watch(driverApiProvider).offers());

final openPickupsProvider =
    FutureProvider.autoDispose<List<AdHocRequest>>((ref) => ref.watch(driverApiProvider).openPickups());

final myPickupsProvider = FutureProvider.autoDispose<List<AdHocRequest>>((ref) => ref.watch(driverApiProvider).myPickups());

final earningsProvider = FutureProvider.autoDispose<Earnings>((ref) => ref.watch(driverApiProvider).earnings());

final driverBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) => ref.watch(driverApiProvider).bookings());
