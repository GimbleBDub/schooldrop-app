import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../models/booking.dart';
import '../../models/child.dart';
import '../../models/school.dart';
import '../../models/trip.dart';

final childrenProvider = FutureProvider.autoDispose<List<Child>>((ref) => ref.watch(parentApiProvider).children());

final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) => ref.watch(parentApiProvider).bookings());

final pickupsProvider = FutureProvider.autoDispose<List<AdHocRequest>>((ref) => ref.watch(parentApiProvider).pickups());

final parentTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(parentApiProvider).tripsToday());

final offersForChildProvider = FutureProvider.autoDispose.family<List<Offer>, String>(
    (ref, childId) => ref.watch(parentApiProvider).offersFor(childId));

final termsProvider = FutureProvider.autoDispose<List<SchoolTerm>>((ref) => ref.watch(commonApiProvider).terms());

/// Call after anything that changes bookings/payments so every tab shows fresh data.
void refreshParentData(WidgetRef ref) {
  ref.invalidate(childrenProvider);
  ref.invalidate(bookingsProvider);
  ref.invalidate(pickupsProvider);
  ref.invalidate(parentTripsProvider);
}
