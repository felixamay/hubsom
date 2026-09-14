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

  /// TURN relay for live WebRTC. STUN alone cannot connect a seller and a
  /// viewer who are both behind carrier NAT, which is the norm on Ghanaian
  /// mobile data, so a relay is what makes live actually reachable.
  static late String turnUrls;
  static late String turnUsername;
  static late String turnCredential;

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
    // Comma-separated. Defaults to the public OpenRelay project so live works
    // out of the box; point these at your own TURN for production traffic.
    turnUrls = const String.fromEnvironment(
      'HUBSOM_TURN_URLS',
      defaultValue: 'turn:openrelay.metered.ca:80,'
          'turn:openrelay.metered.ca:443,'
          'turn:openrelay.metered.ca:443?transport=tcp',
    );
    turnUsername = const String.fromEnvironment(
      'HUBSOM_TURN_USERNAME',
      defaultValue: 'openrelayproject',
    );
    turnCredential = const String.fromEnvironment(
      'HUBSOM_TURN_CREDENTIAL',
      defaultValue: 'openrelayproject',
    );
  }
}
