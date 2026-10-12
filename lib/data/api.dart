import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/config.dart';
import '../models/account.dart';
import '../models/admin.dart';
import '../models/billing.dart';
import '../models/booking.dart';
import '../models/child.dart';
import '../models/common.dart';
import '../models/driver.dart';
import '../models/family.dart';
import '../models/promo.dart';
import '../models/school.dart';
import '../models/trip.dart';
import '../models/user.dart';

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? dateOrNull(DateTime? d) => d == null ? null : _date(d);

final commonApiProvider = Provider((ref) => CommonApi(ref.watch(apiClientProvider)));
final parentApiProvider = Provider((ref) => ParentApi(ref.watch(apiClientProvider)));
final driverApiProvider = Provider((ref) => DriverApi(ref.watch(apiClientProvider)));
final schoolApiProvider = Provider((ref) => SchoolApi(ref.watch(apiClientProvider)));
final kidApiProvider = Provider((ref) => KidApi(ref.watch(apiClientProvider)));
final adminApiProvider = Provider((ref) => AdminApi(ref.watch(apiClientProvider)));
final accountApiProvider = Provider((ref) => AccountApi(ref.watch(apiClientProvider)));
final billingApiProvider = Provider((ref) => BillingApi(ref.watch(apiClientProvider)));

/// Profile & settings — every account type.
class AccountApi {
  AccountApi(this._api);

  final ApiClient _api;

  Future<Account> account() async => Account.fromJson(await _api.get('/account'));

  Future<Account> updateProfile(String firstName, String lastName) async =>
      Account.fromJson(await _api.put('/account/profile', body: {'firstName': firstName, 'lastName': lastName}));

  /// Returns a new sign-in (tokens + profile): every other device is signed out.
  Future<Json> changeEmail(String newEmail, String password, String deviceId, String deviceName) async =>
      await _api.put('/account/email',
          body: {'newEmail': newEmail, 'password': password, 'deviceId': deviceId, 'deviceName': deviceName});

  Future<Account> changePhone(String newPhone, String password) async =>
      Account.fromJson(await _api.put('/account/phone', body: {'newPhone': newPhone, 'password': password}));

  /// Returns a new sign-in (tokens + profile): every other device is signed out.
  Future<Json> changePassword(String current, String next, String deviceId, String deviceName) async =>
      await _api.put('/account/password',
          body: {'currentPassword': current, 'newPassword': next, 'deviceId': deviceId, 'deviceName': deviceName});

  Future<Account> updateNotifications(NotificationSettings settings) async =>
      Account.fromJson(await _api.put('/account/notifications', body: settings.toJson()));

  Future<List<DeviceSession>> sessions(String deviceId) async =>
      parseList(await _api.get('/account/sessions', query: {'deviceId': deviceId}), DeviceSession.fromJson);

  Future<void> signOutSession(String id) => _api.delete('/account/sessions/$id');

  Future<int> signOutOthers(String deviceId) async =>
      ((await _api.post<Json>('/account/sessions/sign-out-others', body: {'deviceId': deviceId}))['signedOut'] as num)
          .toInt();
}

/// Billing for families and drivers: summary, history and documents.
class BillingApi {
  BillingApi(this._api);

  final ApiClient _api;

  Future<BillingSummary> summary() async => BillingSummary.fromJson(await _api.get('/billing/summary'));

  Future<List<MoneyLine>> transactions() async => parseList(await _api.get('/billing/transactions'), MoneyLine.fromJson);

  Future<List<InvoiceSummary>> invoices() async => parseList(await _api.get('/billing/invoices'), InvoiceSummary.fromJson);

  Future<InvoiceDetail> invoice(String id) async => InvoiceDetail.fromJson(await _api.get('/billing/invoices/$id'));

  /// A signed link that opens the PDF in a browser / share sheet for a few minutes.
  Future<Uri> pdfLink(String id) async => _absolute((await _api.post<Json>('/billing/invoices/$id/link'))['path']);
}

Uri _absolute(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

/// Shared by every role: directory, notifications, incidents, password.
class CommonApi {
  CommonApi(this._api);

  final ApiClient _api;

  Future<List<School>> schools({String? query}) async =>
      PageResult.fromJson(await _api.get('/schools', query: {'query': query, 'size': 50}), School.fromJson).content;

  Future<List<SchoolTerm>> terms() async => parseList(await _api.get('/terms'), SchoolTerm.fromJson);

  /// The vehicle colour dropdown (managed by SchoolDrop staff).
  Future<List<String>> vehicleColours() async => ((await _api.get<List>('/vehicle-colours'))).cast<String>();

  Future<PageResult<NotificationItem>> notifications({int page = 0}) async =>
      PageResult.fromJson(await _api.get('/notifications', query: {'page': page}), NotificationItem.fromJson);

  Future<int> unreadCount() async => ((await _api.get<Json>('/notifications/unread-count'))['count'] as num).toInt();

  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<void> reportIncident({required String type, required String description, String? tripId,
      double? latitude, double? longitude}) =>
      _api.post('/incidents', body: {
        'type': type,
        'description': description,
        'tripId': tripId,
        'latitude': latitude,
        'longitude': longitude,
      });

  /// One sponsored card for this parent / school user, or null.
  Future<Advert?> nextAdvert() async {
    final json = await _api.get<dynamic>('/adverts/next');
    return json is Map<String, dynamic> ? Advert.fromJson(json) : null;
  }

  Future<void> advertClicked(String id) => _api.post('/adverts/$id/click');

  /// Status of a payment the signed-in user made (any role).
  Future<Payment> payment(String id) async => Payment.fromJson(await _api.get('/payments/$id'));

  Future<void> completeSandbox(String reference, bool success) =>
      _api.post('/payments/sandbox/$reference/complete', query: {'success': success});

  Future<void> changePassword(String current, String next) =>
      _api.post('/auth/change-password', body: {'currentPassword': current, 'newPassword': next});
}

class ParentApi {
  ParentApi(this._api);

  final ApiClient _api;

  Future<List<Child>> children() async => parseList(await _api.get('/parent/children'), Child.fromJson);

  Future<Child> child(String id) async => Child.fromJson(await _api.get('/parent/children/$id'));

  Future<Child> saveChild(String? id, Json body) async => Child.fromJson(id == null
      ? await _api.post('/parent/children', body: body)
      : await _api.put('/parent/children/$id', body: body));

  Future<void> removeChild(String id) => _api.delete('/parent/children/$id');

  Future<PairingCode> pairingCode(String childId) async =>
      PairingCode.fromJson(await _api.post('/parent/children/$childId/pairing-code'));

  Future<Child> unpair(String childId) async => Child.fromJson(await _api.delete('/parent/children/$childId/device'));

  Future<Household> household() async => Household.fromJson(await _api.get('/parent/household'));

  Future<Invite> inviteFamilyMember(String role, String? name) async =>
      Invite.fromJson(await _api.post('/parent/household/invites', body: {'role': role, 'name': name}));

  Future<void> revokeFamilyInvite(String id) => _api.delete('/parent/household/invites/$id');

  Future<void> removeFamilyMember(String id) => _api.delete('/parent/household/members/$id');

  Future<void> leaveFamily() => _api.post('/parent/household/leave');

  Future<void> joinFamily(String code) => _api.post('/parent/household/join', body: {'code': code.trim()});

  /// stage: PICKUP ("I handed my child over") or DROPOFF ("my child is home").
  Future<Trip> confirmHandover(String passengerId, String stage) async =>
      Trip.fromJson(await _api.post('/parent/passengers/$passengerId/confirm', query: {'stage': stage}));

  Future<Trip> disputeHandover(String passengerId, String reason) async =>
      Trip.fromJson(await _api.post('/parent/passengers/$passengerId/dispute', body: {'reason': reason}));

  Future<Booking> claimPaidDriver(String bookingId) async =>
      Booking.fromJson(await _api.post('/parent/bookings/$bookingId/paid-driver'));

  Future<List<Offer>> offersFor(String childId) async =>
      parseList(await _api.get('/parent/children/$childId/offers'), Offer.fromJson);

  Future<Booking> book(Json body) async => Booking.fromJson(await _api.post('/parent/bookings', body: body));

  Future<List<Booking>> bookings() async => parseList(await _api.get('/parent/bookings'), Booking.fromJson);

  Future<Booking> cancelBooking(String id, String? reason) async => Booking.fromJson(
      await _api.post('/parent/bookings/$id/cancel', body: reason == null ? null : {'reason': reason}));

  Future<Payment> payBooking(String id, String method, String? phone) async => Payment.fromJson(
      await _api.post('/parent/bookings/$id/pay', body: {'method': method, 'payerPhone': phone}));

  Future<AdHocRequest> requestPickup(Json body) async =>
      AdHocRequest.fromJson(await _api.post('/parent/adhoc', body: body));

  Future<List<AdHocRequest>> pickups() async => parseList(await _api.get('/parent/adhoc'), AdHocRequest.fromJson);

  Future<Payment> payPickup(String id, String method, String? phone) async => Payment.fromJson(
      await _api.post('/parent/adhoc/$id/pay', body: {'method': method, 'payerPhone': phone}));

  Future<AdHocRequest> cancelPickup(String id) async =>
      AdHocRequest.fromJson(await _api.post('/parent/adhoc/$id/cancel'));


  Future<List<Payment>> payments() async => parseList(await _api.get('/parent/payments'), Payment.fromJson);

  Future<List<Trip>> tripsToday() async => parseList(await _api.get('/parent/trips/today'), Trip.fromJson);
}

class DriverApi {
  DriverApi(this._api);

  final ApiClient _api;

  Future<DriverProfile> profile() async => DriverProfile.fromJson(await _api.get('/driver/profile'));

  Future<DriverProfile> updateProfile(Json body) async =>
      DriverProfile.fromJson(await _api.put('/driver/profile', body: body));

  Future<DriverProfile> setSchools(List<String> ids) async =>
      DriverProfile.fromJson(await _api.put('/driver/schools', body: {'schoolIds': ids}));

  Future<Vehicle> saveVehicle(String? id, Json body) async => Vehicle.fromJson(id == null
      ? await _api.post('/driver/vehicles', body: body)
      : await _api.put('/driver/vehicles/$id', body: body));

  Future<void> deactivateVehicle(String id) => _api.post('/driver/vehicles/$id/deactivate');

  Future<DriverDocument> uploadDocument({required String type, required List<int> bytes, required String filename,
      String? vehicleId, String? referenceNumber, DateTime? issuedOn, DateTime? expiresOn}) async {
    final form = FormData.fromMap({
      'type': type,
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (referenceNumber != null && referenceNumber.isNotEmpty) 'referenceNumber': referenceNumber,
      if (issuedOn != null) 'issuedOn': _date(issuedOn),
      if (expiresOn != null) 'expiresOn': _date(expiresOn),
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return DriverDocument.fromJson(await _api.post('/driver/documents', body: form));
  }

  Future<DriverProfile> submit() async => DriverProfile.fromJson(await _api.post('/driver/submit'));

  Future<List<Offer>> offers() async => parseList(await _api.get('/driver/offers'), Offer.fromJson);

  Future<Offer> saveOffer(String? id, Json body) async => Offer.fromJson(id == null
      ? await _api.post('/driver/offers', body: body)
      : await _api.put('/driver/offers/$id', body: body));

  Future<List<Booking>> bookings() async => parseList(await _api.get('/driver/bookings'), Booking.fromJson);

  Future<List<AdHocRequest>> openPickups() async =>
      parseList(await _api.get('/driver/adhoc/open'), AdHocRequest.fromJson);

  Future<List<AdHocRequest>> myPickups() async => parseList(await _api.get('/driver/adhoc'), AdHocRequest.fromJson);

  Future<void> acceptPickup(String id) => _api.post('/driver/adhoc/$id/accept');

  Future<void> releasePickup(String id) => _api.post('/driver/adhoc/$id/release');

  Future<void> cancelPickup(String id, String reason) =>
      _api.post('/driver/adhoc/$id/cancel', body: {'reason': reason});

  Future<List<Trip>> trips({DateTime? date}) async =>
      parseList(await _api.get('/driver/trips', query: {'date': dateOrNull(date)}), Trip.fromJson);

  Future<Trip> startTrip(String id) async => Trip.fromJson(await _api.post('/driver/trips/$id/start'));

  Future<void> sendLocation(String id, double lat, double lng) =>
      _api.post('/driver/trips/$id/location', body: {'latitude': lat, 'longitude': lng});

  Future<Trip> pickup(String tripId, String passengerId) async =>
      Trip.fromJson(await _api.post('/driver/trips/$tripId/passengers/$passengerId/pickup'));

  /// handedTo: who received the child at home (required for afternoon drop-offs).
  Future<Trip> dropoff(String tripId, String passengerId, {String? handedTo}) async => Trip.fromJson(
      await _api.post('/driver/trips/$tripId/passengers/$passengerId/dropoff', body: {'handedTo': handedTo}));

  Future<void> confirmDirectPayment(String bookingId, {required bool received}) =>
      _api.post('/driver/bookings/$bookingId/${received ? 'payment-received' : 'payment-not-received'}');

  Future<Subscription> subscription() async => Subscription.fromJson(await _api.get('/driver/subscription'));

  // ─── Team / transport company ───

  Future<Team> team() async => Team.fromJson(await _api.get('/driver/team'));

  Future<Team> createTeam(Json body) async => Team.fromJson(await _api.post('/driver/team', body: body));

  Future<Team> updateTeam(String name, String? registrationNumber) async =>
      Team.fromJson(await _api.put('/driver/team', body: {'name': name, 'registrationNumber': registrationNumber}));

  Future<TeamInvite> inviteToTeam(String role, String? name) async =>
      TeamInvite.fromJson(await _api.post('/driver/team/invites', body: {'role': role, 'name': name}));

  Future<void> revokeTeamInvite(String id) => _api.delete('/driver/team/invites/$id');

  Future<void> joinTeam(String code) => _api.post('/driver/team/join', body: {'code': code.trim()});

  Future<Team> updateTeamMember(String driverId, String role, bool drives) async => Team.fromJson(
      await _api.put('/driver/team/members/$driverId', body: {'role': role, 'drives': drives}));

  Future<void> removeTeamMember(String driverId) => _api.delete('/driver/team/members/$driverId');

  Future<void> leaveTeam() => _api.post('/driver/team/leave');

  Future<List<Trip>> teamTrips({DateTime? date}) async =>
      parseList(await _api.get('/driver/team/trips', query: {'date': dateOrNull(date)}), Trip.fromJson);

  Future<Trip> assignTrip(String tripId, String driverId) async =>
      Trip.fromJson(await _api.post('/driver/team/trips/$tripId/assign', body: {'driverId': driverId}));

  Future<Payment> paySubscription(String method, String? phone) async => Payment.fromJson(
      await _api.post('/driver/subscription/pay', body: {'method': method, 'payerPhone': phone}));

  Future<List<Advert>> adverts() async => parseList(await _api.get('/driver/adverts'), Advert.fromJson);

  Future<Advert> createAdvert(Json body) async => Advert.fromJson(await _api.post('/driver/adverts', body: body));

  Future<Payment> payAdvert(String id, String method, String? phone) async => Payment.fromJson(
      await _api.post('/driver/adverts/$id/pay', body: {'method': method, 'payerPhone': phone}));

  Future<Trip> absent(String tripId, String passengerId) async =>
      Trip.fromJson(await _api.post('/driver/trips/$tripId/passengers/$passengerId/absent'));

  Future<Trip> completeTrip(String id) async => Trip.fromJson(await _api.post('/driver/trips/$id/complete'));

  Future<Earnings> earnings() async => Earnings.fromJson(await _api.get('/driver/earnings'));
}

class SchoolApi {
  SchoolApi(this._api);

  final ApiClient _api;

  Future<School> mySchool() async => School.fromJson(await _api.get('/school/me'));

  Future<School> update(Json body) async => School.fromJson(await _api.put('/school/me', body: body));

  Future<PageResult<SchoolChild>> children({String? status}) async => PageResult.fromJson(
      await _api.get('/school/children', query: {'status': status, 'size': 100}), SchoolChild.fromJson);

  Future<void> confirm(String childId) => _api.post('/school/children/$childId/confirm');

  Future<void> reject(String childId, String reason) =>
      _api.post('/school/children/$childId/reject', body: {'reason': reason});

  Future<List<Trip>> trips({DateTime? date}) async =>
      parseList(await _api.get('/school/trips', query: {'date': dateOrNull(date)}), Trip.fromJson);

  Future<void> release(String passengerId) => _api.post('/school/passengers/$passengerId/release');

  Future<void> confirmArrival(String passengerId) => _api.post('/school/passengers/$passengerId/arrived');

  Future<void> dispute(String passengerId, String reason) =>
      _api.post('/school/passengers/$passengerId/dispute', body: {'reason': reason});

  Future<SchoolStaffList> staff() async => SchoolStaffList.fromJson(await _api.get('/school/staff'));

  Future<Invite> inviteStaff(String role, String? name) async =>
      Invite.fromJson(await _api.post('/school/staff/invites', body: {'role': role, 'name': name}));

  Future<void> revokeStaffInvite(String id) => _api.delete('/school/staff/invites/$id');

  Future<void> removeStaff(String id) => _api.delete('/school/staff/$id');
}

class KidApi {
  KidApi(this._api);

  final ApiClient _api;

  Future<List<Trip>> tripsToday() async => parseList(await _api.get('/kid/trips/today'), Trip.fromJson);

  Future<void> confirm(String passengerId, {required bool pickup}) =>
      _api.post('/kid/passengers/$passengerId/${pickup ? 'confirm-pickup' : 'confirm-dropoff'}');
}

class AdminApi {
  AdminApi(this._api);

  final ApiClient _api;

  Future<Dashboard> dashboard() async => Dashboard.fromJson(await _api.get('/admin/dashboard'));

  Future<List<Trip>> liveTrips() async => parseList(await _api.get('/admin/trips/live'), Trip.fromJson);

  Future<PageResult<DriverSummary>> drivers({String? status, String? query, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/drivers', query: {'status': status, 'query': query, 'page': page}), DriverSummary.fromJson);

  Future<DriverProfile> driver(String id) async => DriverProfile.fromJson(await _api.get('/admin/drivers/$id'));

  Future<void> driverAction(String id, String action, {String? reason}) =>
      _api.post('/admin/drivers/$id/$action', body: reason == null ? null : {'reason': reason});

  Future<void> reviewDocument(String id, bool approve, String? note) =>
      _api.post('/admin/documents/$id/review', body: {'approve': approve, 'note': note});

  Future<List<int>> documentFile(String id) => _api.bytes('/admin/documents/$id/file');

  Future<PageResult<School>> schools({String? status, String? query, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/schools', query: {'status': status, 'query': query, 'page': page}), School.fromJson);

  /// Schools are added by SchoolDrop staff (pinned on the map) — families and drivers choose from them.
  Future<School> saveSchool(String? id, Json body) async => School.fromJson(
      id == null ? await _api.post('/admin/schools', body: body) : await _api.put('/admin/schools/$id', body: body));

  /// An invite code for a school's admin (or staff) to join it.
  Future<Invite> inviteSchoolStaff(String schoolId, String role, String? name) async =>
      Invite.fromJson(await _api.post('/admin/schools/$schoolId/invites', body: {'role': role, 'name': name}));

  Future<List<({String id, String name, bool active})>> vehicleColours() async => [
        for (final c in (await _api.get<List>('/admin/vehicle-colours')))
          (id: c['id'] as String, name: c['name'] as String, active: c['active'] as bool)
      ];

  Future<void> addVehicleColour(String name) => _api.post('/admin/vehicle-colours', body: {'name': name});

  Future<void> setVehicleColourActive(String id, bool active) =>
      _api.post('/admin/vehicle-colours/$id/${active ? 'restore' : 'remove'}');

  Future<void> schoolAction(String id, String action, {String? reason}) =>
      _api.post('/admin/schools/$id/$action', body: reason == null ? null : {'reason': reason});

  Future<PageResult<AdminUser>> users({String? role, String? query, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/users', query: {'role': role, 'query': query, 'page': page}), AdminUser.fromJson);

  Future<void> setUserEnabled(String id, bool enabled, {String? reason}) => _api.post(
      '/admin/users/$id/${enabled ? 'enable' : 'disable'}', body: enabled ? null : {'reason': reason});

  Future<AdminUser> createStaff(Json body) async => AdminUser.fromJson(await _api.post('/admin/staff', body: body));

  Future<List<AdminUser>> staff() async => parseList(await _api.get('/admin/staff'), AdminUser.fromJson);

  /// Signs them out everywhere and returns a new temporary password (shown once).
  Future<AdminUser> resetStaffPassword(String id) async =>
      AdminUser.fromJson(await _api.post('/admin/staff/$id/reset-password'));

  Future<PageResult<InvoiceSummary>> invoices({String? type, String? query, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/invoices', query: {'type': type, 'query': query, 'page': page}), InvoiceSummary.fromJson);

  Future<InvoiceDetail> invoice(String id) async => InvoiceDetail.fromJson(await _api.get('/admin/invoices/$id'));

  Future<Uri> invoicePdfLink(String id) async => _absolute((await _api.post<Json>('/admin/invoices/$id/link'))['path']);

  Future<FinanceReport> finance({int months = 12}) async =>
      FinanceReport.fromJson(await _api.get('/admin/finance', query: {'months': months}));

  Future<void> setPermissions(String id, Set<String> permissions) =>
      _api.put('/admin/staff/$id/permissions', body: {'permissions': permissions.toList()});

  Future<PageResult<Booking>> bookings({String? status, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/bookings', query: {'status': status, 'page': page}), Booking.fromJson);

  Future<void> cancelBooking(String id, String reason, bool refund) =>
      _api.post('/admin/bookings/$id/cancel', body: {'reason': reason}, query: {'refund': refund});

  Future<PageResult<Payment>> payments({String? status, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/payments', query: {'status': status, 'page': page}), Payment.fromJson);

  Future<void> refund(String id, String reason) => _api.post('/admin/payments/$id/refund', body: {'reason': reason});

  Future<PageResult<Payout>> payouts({String? status, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/payouts', query: {'status': status, 'page': page}), Payout.fromJson);

  Future<int> runPayouts() async => ((await _api.post<Json>('/admin/payouts/run'))['created'] as num).toInt();

  Future<void> payoutPaid(String id, String reference) =>
      _api.post('/admin/payouts/$id/paid', body: {'reference': reference});

  Future<void> payoutFailed(String id, String reason) =>
      _api.post('/admin/payouts/$id/failed', body: {'reason': reason});

  Future<PageResult<Incident>> incidents({String? status, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/incidents', query: {'status': status, 'page': page}), Incident.fromJson);

  Future<void> updateIncident(String id, String status, String? resolution) =>
      _api.put('/admin/incidents/$id', body: {'status': status, 'resolution': resolution});

  Future<PageResult<Advert>> adverts({String? status, int page = 0}) async => PageResult.fromJson(
      await _api.get('/admin/adverts', query: {'status': status, 'page': page}), Advert.fromJson);

  Future<void> reviewAdvert(String id, bool approve, String? note) =>
      _api.post('/admin/adverts/$id/review', body: {'approve': approve, 'note': note});

  Future<void> setAdvertPaused(String id, bool paused) => _api.post('/admin/adverts/$id/${paused ? 'pause' : 'resume'}');

  Future<void> createAdvert(Json body) => _api.post('/admin/adverts', body: body);

  Future<List<SchoolTerm>> terms() async => parseList(await _api.get('/admin/terms'), SchoolTerm.fromJson);

  Future<void> saveTerm(String? id, String name, DateTime start, DateTime end) {
    final body = {'name': name, 'startDate': _date(start), 'endDate': _date(end)};
    return id == null ? _api.post('/admin/terms', body: body) : _api.put('/admin/terms/$id', body: body);
  }

  Future<PageResult<AuditEntry>> audit({int page = 0}) async =>
      PageResult.fromJson(await _api.get('/admin/audit', query: {'page': page}), AuditEntry.fromJson);
}
