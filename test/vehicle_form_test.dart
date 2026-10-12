import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldrop/features/driver/driver_providers.dart';
import 'package:schooldrop/features/driver/onboarding_screen.dart';
import 'package:schooldrop/models/driver.dart';

void main() {
  testWidgets('add-vehicle form lays out on a phone screen', (tester) async {
    // iPhone-sized screen, where the old dialog failed to lay out
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [vehicleColoursProvider.overrideWith((ref) async => ['White', 'Silver', 'Red'])],
      child: const MaterialApp(home: VehicleFormPage()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add vehicle'), findsWidgets);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Colour'), findsOneWidget);

    // Children field takes digits only
    final seats = find.widgetWithText(TextFormField, 'Number of children it can carry');
    await tester.enterText(seats, '1a4');
    expect(find.text('14'), findsOneWidget);

    // Colour dropdown opens and lists the colours
    await tester.tap(find.text('Colour'));
    await tester.pumpAndSettle();
    expect(find.text('Silver'), findsWidgets);
  });

  testWidgets('editing a vehicle shows its papers to upload (no insurance)', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final vehicle = Vehicle.fromJson({
      'id': 'v1', 'make': 'Toyota', 'model': 'Quantum', 'year': 2013, 'colour': 'Green', 'plateNumber': 'B637ABC',
      'type': 'MINIBUS', 'seatCapacity': 18, 'active': true, 'verified': false,
    });
    final profile = DriverProfile.fromJson({
      'id': 'd1', 'userId': 'u1', 'fullName': 'K', 'email': 'k@x.bw', 'status': 'PENDING_DOCUMENTS', 'acceptsAdHoc': false,
      'schools': [], 'vehicles': [], 'documents': [], 'missingRequirements': [],
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        vehicleColoursProvider.overrideWith((ref) async => ['Green', 'White']),
        driverProfileProvider.overrideWith((ref) async => profile),
      ],
      child: MaterialApp(home: VehicleFormPage(vehicle: vehicle)),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Papers for B637ABC'), findsOneWidget);
    expect(find.text('Vehicle registration (blue book)'), findsOneWidget);
    expect(find.text('Roadworthy certificate'), findsOneWidget);
    expect(find.text('Photo of the vehicle'), findsOneWidget);
    expect(find.text('Insurance certificate'), findsNothing);
    expect(find.text('Upload'), findsNWidgets(3));
  });
}
