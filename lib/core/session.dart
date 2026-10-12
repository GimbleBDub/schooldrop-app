import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'device.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      ref.watch(tokenStoreProvider),
      onSessionExpired: () => ref.read(sessionProvider.notifier).expire(),
    ));

class SessionState {
  const SessionState({this.user, this.restoring = false, this.expired = false});

  final UserProfile? user;
  final bool restoring;
  final bool expired;

  bool get signedIn => user != null;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Who is signed in. Restores the session from stored tokens at startup.
class SessionController extends Notifier<SessionState> {
  ApiClient get _api => ref.read(apiClientProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionState(restoring: true);
  }

  Future<void> _restore() async {
    if (await _tokens.accessToken == null) {
      state = const SessionState();
      return;
    }
    try {
      state = SessionState(user: UserProfile.fromJson(await _api.get('/auth/me')));
    } catch (_) {
      await _tokens.clear();
      state = const SessionState();
    }
  }

  Future<void> login(String email, String password) =>
      _signIn('/auth/login', {'email': email.trim(), 'password': password});

  /// Creates the account only (accountType: PARENT, DRIVER or SCHOOL); details follow in [completeOnboarding].
  Future<void> register({required String accountType, required String email, required String phone,
          required String password}) =>
      _signIn('/auth/register', {'accountType': accountType, 'email': email.trim(), 'phone': phone.trim(), 'password': password});

  /// Joins a family (parent accounts) or a school (school accounts) with an invite code instead.
  Future<void> joinWithCode({required String firstName, required String lastName, required String code, String? title}) async {
    final user = await _api.put<Map<String, dynamic>>('/onboarding/join',
        body: {'firstName': firstName, 'lastName': lastName, 'code': code.trim(), 'title': title});
    state = SessionState(user: UserProfile.fromJson(user));
  }

  /// Re-reads the profile (e.g. after joining a family from settings).
  Future<void> refreshProfile() async {
    state = SessionState(user: UserProfile.fromJson(await _api.get('/auth/me')));
  }

  /// Sends the onboarding details for the signed-in account's type and unlocks the app.
  Future<void> completeOnboarding(Map<String, dynamic> body) async {
    final role = state.user!.role.toLowerCase();
    final user = await _api.put<Map<String, dynamic>>('/onboarding/$role', body: body);
    state = SessionState(user: UserProfile.fromJson(user));
  }

  Future<void> pairKid(String code) => _signIn('/auth/kid/pair', {'code': code.trim()});

  Future<void> _signIn(String path, Map<String, dynamic> body) async {
    final response = await _api.post<Map<String, dynamic>>(path,
        body: {...body, 'deviceId': await _tokens.deviceId(), 'deviceName': deviceName()}, auth: false);
    await applySignIn(response);
  }

  /// Stores a new sign-in (after login, or after an email / password change re-issued the tokens).
  Future<void> applySignIn(Map<String, dynamic> response) async {
    await _tokens.save(response['accessToken'], response['refreshToken']);
    state = SessionState(user: UserProfile.fromJson(response['user']));
  }

  /// After a profile change that didn't re-issue tokens (name, phone).
  void updateUser(UserProfile user) => state = SessionState(user: user);

  Future<String> deviceId() => _tokens.deviceId();

  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken;
    try {
      // Signs out only this device
      await _api.post('/auth/logout', body: {'refreshToken': refreshToken});
    } catch (_) {
      // Already invalid — nothing to revoke
    }
    await _tokens.clear();
    state = const SessionState();
  }

  void expire() {
    _tokens.clear();
    state = const SessionState(expired: true);
  }
}
