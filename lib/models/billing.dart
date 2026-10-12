import 'common.dart';

double _m(Object? v) => parseMoney(v) ?? 0;

class FamilyMonth {
  FamilyMonth(this.month, this.paidInApp, this.paidDirect, this.refunded);

  final DateTime month;
  final double paidInApp;
  final double paidDirect;
  final double refunded;

  factory FamilyMonth.fromJson(Json j) =>
      FamilyMonth(_month(j['month']), _m(j['paidInApp']), _m(j['paidDirect']), _m(j['refunded']));
}

class DriverMonth {
  DriverMonth(this.month, this.grossInApp, this.commission, this.net, this.paidDirect, this.paidToSchoolDrop);

  final DateTime month;
  final double grossInApp;
  final double commission;
  final double net;
  final double paidDirect;
  final double paidToSchoolDrop;

  factory DriverMonth.fromJson(Json j) => DriverMonth(_month(j['month']), _m(j['grossInApp']), _m(j['commission']),
      _m(j['net']), _m(j['paidDirect']), _m(j['paidToSchoolDrop']));
}

DateTime _month(Object? v) {
  final parts = (v as String).split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

class FamilyBilling {
  FamilyBilling.fromJson(Json j)
      : paidThisMonth = _m(j['paidThisMonth']),
        paidThisYear = _m(j['paidThisYear']),
        paidAllTime = _m(j['paidAllTime']),
        paidDirectAllTime = _m(j['paidDirectAllTime']),
        refundedAllTime = _m(j['refundedAllTime']),
        awaitingPaymentCount = j['awaitingPaymentCount'] as int,
        awaitingPaymentAmount = _m(j['awaitingPaymentAmount']),
        byChild = [for (final c in (j['byChild'] as List)) (name: c['label'] as String, total: _m(c['total']))],
        months = parseList(j['months'], FamilyMonth.fromJson);

  final double paidThisMonth;
  final double paidThisYear;
  final double paidAllTime;
  final double paidDirectAllTime;
  final double refundedAllTime;
  final int awaitingPaymentCount;
  final double awaitingPaymentAmount;
  final List<({String name, double total})> byChild;
  final List<FamilyMonth> months;
}

class DriverBilling {
  DriverBilling.fromJson(Json j)
      : commissionPercent = _m(j['commissionPercent']),
        earnedThisMonth = _m(j['earnedThisMonth']),
        earnedThisYear = _m(j['earnedThisYear']),
        grossAllTime = _m(j['grossAllTime']),
        commissionAllTime = _m(j['commissionAllTime']),
        netAllTime = _m(j['netAllTime']),
        paidDirectAllTime = _m(j['paidDirectAllTime']),
        refundedAllTime = _m(j['refundedAllTime']),
        availableBalance = _m(j['availableBalance']),
        upcomingBalance = _m(j['upcomingBalance']),
        paidOutAllTime = _m(j['paidOutAllTime']),
        paidToSchoolDropAllTime = _m(j['paidToSchoolDropAllTime']),
        listingFeesAllTime = _m(j['listingFeesAllTime']),
        advertsAllTime = _m(j['advertsAllTime']),
        listedUntil = parseDate(j['listedUntil']),
        months = parseList(j['months'], DriverMonth.fromJson);

  final double commissionPercent;
  final double earnedThisMonth;
  final double earnedThisYear;
  final double grossAllTime;
  final double commissionAllTime;
  final double netAllTime;
  final double paidDirectAllTime;
  final double refundedAllTime;
  final double availableBalance;
  final double upcomingBalance;
  final double paidOutAllTime;
  final double paidToSchoolDropAllTime;
  final double listingFeesAllTime;
  final double advertsAllTime;
  final DateTime? listedUntil;
  final List<DriverMonth> months;
}

class BillingSummary {
  BillingSummary({required this.kind, this.family, this.driver});

  final String kind; // FAMILY or DRIVER
  final FamilyBilling? family;
  final DriverBilling? driver;

  factory BillingSummary.fromJson(Json j) => BillingSummary(
        kind: j['kind'],
        family: j['family'] == null ? null : FamilyBilling.fromJson(j['family']),
        driver: j['driver'] == null ? null : DriverBilling.fromJson(j['driver']),
      );
}

/// One line of money history. Negative = money out, positive = money in. Payouts are informational.
class MoneyLine {
  MoneyLine({required this.id, required this.date, required this.kind, required this.title, required this.subtitle,
      required this.amount, required this.status, this.method, this.paidDirectly = false, this.gross, this.commission,
      this.invoiceId, this.invoiceNumber});

  final String id;
  final DateTime date;
  final String kind; // PAYMENT, REFUND, EARNING, EARNING_REFUNDED, FEE, PAYOUT
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final String? method;
  final bool paidDirectly;
  final double? gross;
  final double? commission;
  final String? invoiceId;
  final String? invoiceNumber;

  factory MoneyLine.fromJson(Json j) => MoneyLine(
        id: j['id'],
        date: parseDate(j['date'])!,
        kind: j['kind'],
        title: j['title'],
        subtitle: j['subtitle'],
        amount: _m(j['amount']),
        status: j['status'],
        method: j['method'],
        paidDirectly: j['paidDirectly'] as bool? ?? false,
        gross: parseMoney(j['gross']),
        commission: parseMoney(j['commission']),
        invoiceId: j['invoiceId'],
        invoiceNumber: j['invoiceNumber'],
      );
}

class InvoiceSummary {
  InvoiceSummary({required this.id, required this.number, required this.type, required this.title,
      required this.description, required this.total, required this.paidDirectly, required this.recipientName,
      required this.issuedAt});

  final String id;
  final String number;
  final String type; // RECEIPT, INVOICE, CREDIT_NOTE, STATEMENT
  final String title;
  final String description;
  final double total;
  final bool paidDirectly;
  final String recipientName;
  final DateTime issuedAt;

  factory InvoiceSummary.fromJson(Json j) => InvoiceSummary(
        id: j['id'],
        number: j['number'],
        type: j['type'],
        title: j['title'],
        description: j['description'],
        total: _m(j['total']),
        paidDirectly: j['paidDirectly'] as bool? ?? false,
        recipientName: j['recipientName'],
        issuedAt: parseDate(j['issuedAt'])!,
      );
}

class InvoiceLine {
  InvoiceLine(this.description, this.quantity, this.unitAmount, this.amount);

  final String description;
  final double quantity;
  final double unitAmount;
  final double amount;
}

class InvoiceDetail {
  InvoiceDetail.fromJson(Json j)
      : id = j['id'],
        number = j['number'],
        type = j['type'],
        title = j['title'],
        description = j['description'],
        recipientName = j['recipientName'],
        recipientEmail = j['recipientEmail'],
        recipientPhone = j['recipientPhone'],
        supplierName = j['supplierName'],
        subtotal = _m(j['subtotal']),
        tax = _m(j['tax']),
        vatPercent = parseMoney(j['vatPercent']),
        total = _m(j['total']),
        paymentMethod = j['paymentMethod'],
        paidDirectly = j['paidDirectly'] as bool? ?? false,
        paidAt = parseDate(j['paidAt']),
        notes = j['notes'],
        issuedAt = parseDate(j['issuedAt'])!,
        creditedInvoiceNumber = j['creditedInvoiceNumber'],
        lines = [
          for (final l in (j['lines'] as List))
            InvoiceLine(l['description'], _m(l['quantity']), _m(l['unitAmount']), _m(l['amount']))
        ],
        issuerName = j['issuer']['name'],
        issuerAddress = j['issuer']['address'],
        issuerRegistration = j['issuer']['registration'],
        issuerVatNumber = j['issuer']['vatNumber'],
        supportEmail = j['issuer']['supportEmail'];

  final String id;
  final String number;
  final String type;
  final String title;
  final String description;
  final String recipientName;
  final String? recipientEmail;
  final String? recipientPhone;
  final String supplierName;
  final double subtotal;
  final double tax;
  final double? vatPercent;
  final double total;
  final String? paymentMethod;
  final bool paidDirectly;
  final DateTime? paidAt;
  final String? notes;
  final DateTime issuedAt;
  final String? creditedInvoiceNumber;
  final List<InvoiceLine> lines;
  final String issuerName;
  final String? issuerAddress;
  final String? issuerRegistration;
  final String? issuerVatNumber;
  final String supportEmail;
}

class FinanceMonth {
  FinanceMonth.fromJson(Json j)
      : month = j['month'] == 'total' ? null : _month(j['month']),
        collectedInApp = _m(j['collectedInApp']),
        commission = _m(j['commission']),
        listingFees = _m(j['listingFees']),
        adverts = _m(j['adverts']),
        refunded = _m(j['refunded']),
        refundedCommission = _m(j['refundedCommission']),
        revenue = _m(j['revenue']),
        paidDirect = _m(j['paidDirect']),
        payoutsSent = _m(j['payoutsSent']);

  final DateTime? month;
  final double collectedInApp;
  final double commission;
  final double listingFees;
  final double adverts;
  final double refunded;
  final double refundedCommission;
  final double revenue;
  final double paidDirect;
  final double payoutsSent;
}

class FinanceReport {
  FinanceReport.fromJson(Json j)
      : commissionPercent = _m(j['commissionPercent']),
        totals = FinanceMonth.fromJson(j['totals']),
        months = parseList(j['months'], FinanceMonth.fromJson);

  final double commissionPercent;
  final FinanceMonth totals;
  final List<FinanceMonth> months;
}
