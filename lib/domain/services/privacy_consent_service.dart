import 'package:shared_preferences/shared_preferences.dart';

/// Keys used for persisting consent decisions.
class _Keys {
  static const analyticsOptIn = 'privacy_analytics_opt_in';
  static const consentVersion = 'privacy_consent_version';
  static const consentAcknowledgedAt = 'privacy_consent_acknowledged_at';
}

/// Manages user privacy consent choices for optional data features.
///
/// All choices are persisted locally via [SharedPreferences]. Nothing is
/// transmitted remotely — this service only tracks user-stated preferences.
///
/// Current consent flags:
/// - **analyticsOptIn**: whether anonymous aggregate analytics events may be
///   collected. Defaults to `false` (off until the user explicitly enables).
///
/// The service also provides [acknowledgePrivacyPolicy] to record that the
/// user has reviewed the policy (version-stamped) and
/// [deleteAllLocalData] to clear the consent record alongside other data.
class PrivacyConsentService {
  static const int currentPolicyVersion = 1;

  final SharedPreferences _prefs;

  const PrivacyConsentService(this._prefs);

  // ---------------------------------------------------------------------------
  // Analytics consent
  // ---------------------------------------------------------------------------

  /// Whether the user has opted in to anonymous analytics collection.
  ///
  /// Default: `false` — analytics are off until explicitly enabled.
  bool get analyticsOptIn =>
      _prefs.getBool(_Keys.analyticsOptIn) ?? false;

  /// Set the analytics opt-in state.
  ///
  /// Persists immediately. Returns the new value.
  Future<bool> setAnalyticsOptIn(bool value) async {
    await _prefs.setBool(_Keys.analyticsOptIn, value);
    return value;
  }

  // ---------------------------------------------------------------------------
  // Policy acknowledgement
  // ---------------------------------------------------------------------------

  /// The version of the privacy policy the user last acknowledged.
  ///
  /// Returns `null` if they have never acknowledged any version.
  int? get acknowledgedPolicyVersion =>
      _prefs.getInt(_Keys.consentVersion);

  /// The ISO-8601 timestamp when the current version was acknowledged.
  String? get acknowledgedAt =>
      _prefs.getString(_Keys.consentAcknowledgedAt);

  /// Whether the user has acknowledged the current policy version.
  bool get hasAcknowledgedCurrentPolicy =>
      acknowledgedPolicyVersion == currentPolicyVersion;

  /// Record that the user has read and acknowledged [currentPolicyVersion].
  Future<void> acknowledgePrivacyPolicy() async {
    await _prefs.setInt(_Keys.consentVersion, currentPolicyVersion);
    await _prefs.setString(
      _Keys.consentAcknowledgedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ---------------------------------------------------------------------------
  // Data deletion
  // ---------------------------------------------------------------------------

  /// Clear all locally persisted consent flags.
  ///
  /// Called as part of Settings → Privacy → Delete All Data.
  /// This does NOT delete habit or log data — callers must orchestrate the
  /// full deletion across repositories separately.
  Future<void> clearConsentFlags() async {
    await _prefs.remove(_Keys.analyticsOptIn);
    await _prefs.remove(_Keys.consentVersion);
    await _prefs.remove(_Keys.consentAcknowledgedAt);
  }

  // ---------------------------------------------------------------------------
  // Summary (for the UI)
  // ---------------------------------------------------------------------------

  /// A human-readable summary of the current consent state.
  ConsentSummary get summary => ConsentSummary(
        analyticsOptIn: analyticsOptIn,
        hasAcknowledgedCurrentPolicy: hasAcknowledgedCurrentPolicy,
        acknowledgedPolicyVersion: acknowledgedPolicyVersion,
        acknowledgedAt: acknowledgedAt,
        currentPolicyVersion: currentPolicyVersion,
      );
}

/// Snapshot of the user's current consent choices.
class ConsentSummary {
  final bool analyticsOptIn;
  final bool hasAcknowledgedCurrentPolicy;
  final int? acknowledgedPolicyVersion;
  final String? acknowledgedAt;
  final int currentPolicyVersion;

  const ConsentSummary({
    required this.analyticsOptIn,
    required this.hasAcknowledgedCurrentPolicy,
    required this.acknowledgedPolicyVersion,
    required this.acknowledgedAt,
    required this.currentPolicyVersion,
  });
}
