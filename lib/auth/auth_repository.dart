import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client, GoogleSignIn? googleSignIn})
    : _client = client,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient? _client;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  bool get isConfigured => _client != null;
  SupabaseClient? get client => _client;
  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;

  Stream<AuthState> get authChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  SupabaseClient _requiredClient() {
    final client = _client;
    if (client == null) {
      throw const AuthConfigurationException();
    }
    return client;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => _requiredClient().auth.signInWithPassword(
    email: email.trim(),
    password: password,
  );

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) => _requiredClient().auth.signUp(
    email: email.trim(),
    password: password,
    emailRedirectTo: AppConfig.authRedirect,
  );

  Future<void> sendPasswordReset(String email) => _requiredClient().auth
      .resetPasswordForEmail(email.trim(), redirectTo: AppConfig.authRedirect);

  Future<UserResponse> updatePassword(String password) =>
      _requiredClient().auth.updateUser(UserAttributes(password: password));

  Future<AuthResponse?> signInWithGoogle() async {
    final client = _requiredClient();
    if (kIsWeb) {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.authRedirect,
      );
      return null;
    }
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const AuthConfigurationException(
        'GOOGLE_WEB_CLIENT_ID is missing.',
      );
    }
    if (!_googleInitialized) {
      await _googleSignIn.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _googleInitialized = true;
    }
    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final authorization = await account.authorizationClient
        .authorizationForScopes(const []);
    final idToken = authentication.idToken;
    if (idToken == null) throw const AuthException('Missing Google ID token.');
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
  }

  Future<void> signOut() async {
    await _requiredClient().auth.signOut();
    if (!kIsWeb && _googleInitialized) {
      await _googleSignIn.signOut();
    }
  }

  Future<void> deleteAccount() async {
    final response = await _requiredClient().functions.invoke(
      'delete-account',
      method: HttpMethod.post,
    );
    if (response.status < 200 || response.status >= 300) {
      throw AuthException('Account deletion failed (${response.status}).');
    }
  }
}

class AuthConfigurationException implements Exception {
  const AuthConfigurationException([
    this.message = 'Cloud accounts are not configured in this build.',
  ]);

  final String message;

  @override
  String toString() => message;
}
