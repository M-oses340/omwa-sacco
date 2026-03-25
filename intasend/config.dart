// IntaSend API configuration
// Secret key is NEVER stored here — it lives in Supabase edge function env vars

class IntaSendConfig {
  static const bool isSandbox = true; // flip to false for production

  static const String baseUrl = isSandbox
      ? 'https://sandbox.intasend.com/api/v1'
      : 'https://payment.intasend.com/api/v1';

  // Public key only — safe for Flutter
  // Set via --dart-define or environment config
  static const String publishableKey = String.fromEnvironment(
    'INTASEND_PUBLISHABLE_KEY',
    defaultValue: '',
  );
}
