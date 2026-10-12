import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldrop/features/driver/driver_providers.dart';
import 'package:schooldrop/features/driver/onboarding_screen.dart';
import 'package:schooldrop/models/driver.dart';

DriverProfile _profile() => DriverProfile.fromJson({
      'id': 'd1',
      'userId': 'u1',
      'fullName': 'Kabo Driver',
      'email': 'k@x.bw',
      'status': 'PENDING_DOCUMENTS',
      'acceptsAdHoc': false,
      'omangNumber': '*****6789',
      'dateOfBirth': '1990-01-01',
      'licenceNumber': '***123',
      'licenceCode': 'B',
      'payoutMethod': 'ORANGE_MONEY',
      'payoutAccount': '*****222',
      'schools': [
        {'id': 's1', 'name': 'Demo Primary', 'address': 'Plot 1', 'city': 'Gaborone', 'status': 'VERIFIED'}
      ],
      'vehicles': [
        {'id': 'v1', 'make': 'Toyota', 'model': 'Quantum', 'plateNumber': 'B637ABC', 'type': 'MINIBUS', 'seatCapacity': 14,
          'active': true, 'verified': false}
      ],
      'documents': [],
      'missingRequirements': [
        'vehicle registration for B637ABC',
        'roadworthy certificate for B637ABC',
        'vehicle photo for B637ABC',
      ],
      'drives': true,
      'managesRoutes': true,
      'ownsBusiness': true,
    });

void main() {
  testWidgets('the wizard opens on the vehicle with its missing papers and Upload buttons showing', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 3200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [driverProfileProvider.overrideWith((ref) async => _profile())],
      child: const MaterialApp(home: Scaffold(body: OnboardingScreen())),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Opens on the first unfinished step: the vehicle, with its four papers and Upload buttons showing
    expect(find.textContaining('0 of 3 done').hitTestable(), findsOneWidget);
    expect(find.text('Vehicle registration (blue book)').hitTestable(), findsOneWidget);
    expect(find.text('Upload').hitTestable(), findsNWidgets(3));

    // From Submit, "Fix" goes back to the vehicle step
  });
}
