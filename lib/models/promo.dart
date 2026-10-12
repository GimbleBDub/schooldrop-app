import 'common.dart';

class Subscription {
  Subscription({required this.monthlyFee, required this.active, required this.daysLeft, this.paidUntil,
      this.feePerDriver, this.drivers = 1, this.canPay = true, this.teamName});

  /// Next month's total: [feePerDriver] × [drivers].
  final double monthlyFee;
  final double? feePerDriver;
  final int drivers;

  /// Team drivers see the team's status; the owner pays.
  final bool canPay;
  final String? teamName;
  final bool active;
  final DateTime? paidUntil;
  final int daysLeft;

  factory Subscription.fromJson(Json j) => Subscription(
        monthlyFee: parseMoney(j['monthlyFee'])!,
        active: j['active'] as bool,
        paidUntil: parseDate(j['paidUntil']),
        daysLeft: (j['daysLeft'] as num).toInt(),
        feePerDriver: parseMoney(j['feePerDriver']),
        drivers: (j['drivers'] as num?)?.toInt() ?? 1,
        canPay: j['canPay'] as bool? ?? true,
        teamName: j['teamName'],
      );
}

class Advert {
  Advert({
    required this.id,
    required this.advertiserName,
    required this.title,
    required this.body,
    required this.status,
    required this.fromDriver,
    this.ctaLabel,
    this.ctaPhone,
    this.ctaUrl,
    this.targetSchoolName,
    this.reviewNote,
    this.endsAt,
    this.price,
    this.impressions = 0,
    this.clicks = 0,
  });

  final String id;
  final String advertiserName;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaPhone;
  final String? ctaUrl;
  final String? targetSchoolName;
  final String status; // PENDING_PAYMENT, PENDING_REVIEW, ACTIVE, REJECTED, PAUSED, EXPIRED
  final String? reviewNote;
  final DateTime? endsAt;
  final double? price;
  final int impressions;
  final int clicks;
  final bool fromDriver;

  factory Advert.fromJson(Json j) => Advert(
        id: j['id'],
        advertiserName: j['advertiserName'],
        title: j['title'],
        body: j['body'],
        ctaLabel: j['ctaLabel'],
        ctaPhone: j['ctaPhone'],
        ctaUrl: j['ctaUrl'],
        targetSchoolName: j['targetSchoolName'],
        status: j['status'],
        reviewNote: j['reviewNote'],
        endsAt: parseDate(j['endsAt']),
        price: parseMoney(j['price']),
        impressions: (j['impressions'] as num? ?? 0).toInt(),
        clicks: (j['clicks'] as num? ?? 0).toInt(),
        fromDriver: j['fromDriver'] as bool? ?? false,
      );
}
