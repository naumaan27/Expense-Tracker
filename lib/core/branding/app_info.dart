/// Everything the app knows about itself and who made it.
///
/// [version] and [buildNumber] mirror the `version:` line in `pubspec.yaml`.
/// They are constants rather than a `package_info_plus` lookup on purpose: that
/// plugin answers over a platform channel, which means every widget test that
/// renders the About screen would need a mock, and the value would be
/// unavailable in a pure Dart test. `test/branding_test.dart` parses the
/// pubspec and fails the build if these ever drift out of sync — which buys the
/// same guarantee as the plugin, for no dependency and no mocking.
class AppInfo {
  const AppInfo._();

  static const name = 'Net Worth';
  static const tagline = 'Money, tracked honestly.';

  /// Shown under the wordmark on the About screen.
  static const description =
      'Offline-first personal finance. Your ledger, budgets and dues live '
      'on this device — nothing is ever uploaded.';

  // ── Version ────────────────────────────────────────────────────────────────
  static const version = '1.6.3';
  static const buildNumber = 22;

  /// `1.0.0 (build 1)` — the string a bug report should quote.
  static const versionLabel = '$version (build $buildNumber)';

  // ── Developer ──────────────────────────────────────────────────────────────
  // >>> EDIT YOUR DETAILS HERE <<<
  static const developer = 'Abdul Wadood Naumaan';
  static const developerRole = 'Developer & Creator';

  static const linkedinHandle = 'abdulnaumaan';
  static const linkedinUrl = 'https://www.linkedin.com/in/abdulnaumaan/';

  static const personalEmail = 'workoholic.2718@gmail.com';
  static const feedbackEmail = 'workoholic.2718@gmail.com';

  static const instagramHandle = 'abdulnaumaan';
  static const instagramUrl = 'https://www.instagram.com/abdulnaumaan/';

  static const githubHandle = '';
  static const githubUrl = '';
  static const sponsorUrl = '';

  // ── Project ────────────────────────────────────────────────────────────────
  /// Where this build's source lives.
  static const repoUrl = 'https://github.com/PATILYASHH/XPENC';

  /// The project website — features, downloads, FAQ.
  static const websiteUrl = 'https://xpenc.in';

  /// New issue with a template picker (bug / feature / bank support).
  static const issuesUrl = '$repoUrl/issues/new/choose';

  /// Latest published APKs + SHA-256 checksums.
  static const releasesUrl = '$repoUrl/releases/latest';

  /// Android application id — the same on Play and F-Droid.
  static const packageId = 'com.yash.xpenc';


  /// Play Store listing. The `market://` form opens the Play Store app
  /// directly; the https one is the fallback and what gets shared.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageId';
  static const playStoreMarketUrl = 'market://details?id=$packageId';

  static const fdroidUrl = 'https://f-droid.org/packages/$packageId/';

  /// What "Share XPENC" sends.
  static const shareText =
      'I track my money with $name — offline, private, no ads. '
      'Get it on Google Play: $playStoreUrl';

  static const licenseName = 'MIT License';
  static const licenseUrl = '$repoUrl/blob/master/LICENSE';

  static const copyright = '© 2026 Net Worth';
}
