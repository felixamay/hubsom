class AppConfig {
  static late String apiBaseUrl;
  static late String adminApiKey;
  static late String agoraAppId;
  static late String stripePublishableKey;
  static late String paystackPublicKey;
  static late String openRouteServiceKey;
  static late bool firebaseEnabled;

  /// Google Cloud Storage bucket for shop videos. Empty means "use the one in
  /// firebase_options" — set it to point at a bucket you created yourself,
  /// e.g. --dart-define=HUBSOM_STORAGE_BUCKET=hubsom-videos
  static late String storageBucket;

  static void load() {
    apiBaseUrl = const String.fromEnvironment(
      'HUBSOM_API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );
    adminApiKey = const String.fromEnvironment('HUBSOM_ADMIN_API_KEY', defaultValue: '');
    agoraAppId = const String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
    stripePublishableKey =
        const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
    paystackPublicKey =
        const String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');
    openRouteServiceKey =
        const String.fromEnvironment('OPENROUTESERVICE_KEY', defaultValue: '');
    firebaseEnabled =
        const bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: true);
    storageBucket =
        const String.fromEnvironment('HUBSOM_STORAGE_BUCKET', defaultValue: '');
  }
}
