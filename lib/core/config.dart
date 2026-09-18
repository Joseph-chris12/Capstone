/// Build-time configuration.
///
/// Supplied with --dart-define so keys never live in the repo:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
///
/// The publishable (anon) key is safe to ship: RLS restricts it to reading
/// published artworks. The service role key is never used by the app — only by
/// tools/compile-targets.
class Config {
  const Config._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase renamed the anon key to the "publishable key". Both define names
  /// are accepted so older run configurations keep working.
  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Port for the in-app server that hosts the bundled AR page. Anything
  /// unused works; the page must be served over http://localhost rather than
  /// file:// because getUserMedia requires a secure context, and localhost
  /// counts as one while file:// does not.
  static const localServerPort = 8080;

  static const targetsBucket = 'ar-targets';
  static const videosBucket = 'ar-videos';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static String get configurationError =>
      'Supabase is not configured. Run with:\n'
      '  --dart-define=SUPABASE_URL=...\n'
      '  --dart-define=SUPABASE_PUBLISHABLE_KEY=...';
}
