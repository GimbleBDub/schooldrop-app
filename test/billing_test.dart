import 'package:flutter_test/flutter_test.dart';
import 'package:schooldrop/models/billing.dart';
import 'package:schooldrop/models/user.dart';

void main() {
  test('driver billing summary parses months and money', () {
    final s = BillingSummary.fromJson({
      'kind': 'DRIVER',
      'currency': 'BWP',
      'driver': {
        'commissionPercent': 10,
        'earnedThisMonth': 585.0,
        'earnedThisYear': 585,
        'grossAllTime': 650,
        'commissionAllTime': 65,
        'netAllTime': 585,
        'paidDirectAllTime': 0,
        'refundedAllTime': 0,
        'availableBalance': 0,
        'upcomingBalance': 0,
        'paidOutAllTime': 0,
        'paidToSchoolDropAllTime': 50,
        'listingFeesAllTime': 50,
        'advertsAllTime': 0,
        'listedUntil': '2026-11-07',
        'months': [
          {'month': '2026-10', 'grossInApp': 650, 'commission': 65, 'net': 585, 'paidDirect': 0, 'paidToSchoolDrop': 50},
        ],
      },
    });
    expect(s.kind, 'DRIVER');
    expect(s.driver!.netAllTime, 585);
    expect(s.driver!.months.single.month, DateTime(2026, 10));
    expect(s.driver!.listedUntil, isNotNull);
  });

  test('invoice detail parses lines including deductions', () {
    final d = InvoiceDetail.fromJson({
      'id': 'i1',
      'number': 'STM-2026-000001',
      'type': 'STATEMENT',
      'title': 'Payout statement',
      'description': 'Payout of P540',
      'recipientName': 'Kabo',
      'supplierName': 'SchoolDrop (Pty) Ltd',
      'subtotal': 600,
      'tax': 0,
      'total': 540,
      'paidDirectly': false,
      'issuedAt': '2026-10-08T13:00:00Z',
      'lines': [
        {'description': 'Paid by Ama', 'quantity': 1, 'unitAmount': 600, 'amount': 600},
        {'description': 'SchoolDrop commission', 'quantity': 1, 'unitAmount': -60, 'amount': -60},
      ],
      'issuer': {'name': 'SchoolDrop (Pty) Ltd', 'supportEmail': 'support@schooldrop.co.bw'},
    });
    expect(d.lines.last.amount, -60);
    expect(d.total, 540);
  });

  test('helpers have no billing; staff see their permissions', () {
    final helper = UserProfile.fromJson({'id': '1', 'email': 'h@x.bw', 'role': 'PARENT', 'householdRole': 'HELPER'});
    final guardian = UserProfile.fromJson({'id': '2', 'email': 'g@x.bw', 'role': 'PARENT', 'householdRole': 'GUARDIAN'});
    final finance = UserProfile.fromJson({'id': '3', 'email': 'f@x.bw', 'role': 'ADMIN', 'staffPermissions': ['FINANCE']});
    expect(helper.hasBilling, isFalse);
    expect(guardian.hasBilling, isTrue);
    expect(finance.roleDescription, 'SchoolDrop · Finance');
  });
}
