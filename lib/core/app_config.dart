import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const webAuthRedirect = String.fromEnvironment('WEB_AUTH_REDIRECT');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static String get authRedirect => kIsWeb
      ? (webAuthRedirect.isEmpty
            ? '${Uri.base.origin}/auth/callback'
            : webAuthRedirect)
      : 'tomera://auth-callback';
}
