import 'package:flutter_test/flutter_test.dart';
import 'package:habit_flow/domain/services/privacy_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PrivacyConsentService> makeService(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return PrivacyConsentService(prefs);
  }

  // ---------------------------------------------------------------------------
  // Analytics opt-in defaults
  // ---------------------------------------------------------------------------
  group('PrivacyConsentService — analytics opt-in', () {
    test('defaults to false (opt-out by default)', () async {
      final svc = await makeService();
      expect(svc.analyticsOptIn, isFalse);
    });

    test('setAnalyticsOptIn(true) persists and returns true', () async {
      final svc = await makeService();
      final result = await svc.setAnalyticsOptIn(true);
      expect(result, isTrue);
      expect(svc.analyticsOptIn, isTrue);
    });

    test('setAnalyticsOptIn(false) after true reverts to false', () async {
      final svc = await makeService({'privacy_analytics_opt_in': true});
      await svc.setAnalyticsOptIn(false);
      expect(svc.analyticsOptIn, isFalse);
    });

    test('reads pre-existing true value from prefs', () async {
      final svc = await makeService({'privacy_analytics_opt_in': true});
      expect(svc.analyticsOptIn, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Policy acknowledgement
  // ---------------------------------------------------------------------------
  group('PrivacyConsentService — policy acknowledgement', () {
    test('acknowledgedPolicyVersion is null before acknowledgement', () async {
      final svc = await makeService();
      expect(svc.acknowledgedPolicyVersion, isNull);
    });

    test('acknowledgedAt is null before acknowledgement', () async {
      final svc = await makeService();
      expect(svc.acknowledgedAt, isNull);
    });

    test('hasAcknowledgedCurrentPolicy is false before acknowledgement',
        () async {
      final svc = await makeService();
      expect(svc.hasAcknowledgedCurrentPolicy, isFalse);
    });

    test('acknowledgePrivacyPolicy sets version and timestamp', () async {
      final svc = await makeService();
      await svc.acknowledgePrivacyPolicy();
      expect(svc.acknowledgedPolicyVersion,
          PrivacyConsentService.currentPolicyVersion);
      expect(svc.acknowledgedAt, isNotNull);
    });

    test('hasAcknowledgedCurrentPolicy is true after acknowledgement',
        () async {
      final svc = await makeService();
      await svc.acknowledgePrivacyPolicy();
      expect(svc.hasAcknowledgedCurrentPolicy, isTrue);
    });

    test('acknowledgedAt is a valid ISO-8601 timestamp', () async {
      final svc = await makeService();
      await svc.acknowledgePrivacyPolicy();
      final ts = DateTime.tryParse(svc.acknowledgedAt!);
      expect(ts, isNotNull);
    });

    test('acknowledging older version leaves hasAcknowledgedCurrentPolicy false',
        () async {
      // Simulate a stale version stored in prefs.
      final svc = await makeService({'privacy_consent_version': 0});
      expect(svc.hasAcknowledgedCurrentPolicy, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // clearConsentFlags
  // ---------------------------------------------------------------------------
  group('PrivacyConsentService — clearConsentFlags', () {
    test('clears analytics opt-in', () async {
      final svc = await makeService({'privacy_analytics_opt_in': true});
      await svc.clearConsentFlags();
      expect(svc.analyticsOptIn, isFalse);
    });

    test('clears policy version', () async {
      final svc = await makeService({
        'privacy_consent_version': 1,
        'privacy_consent_acknowledged_at': '2024-06-01T00:00:00.000Z',
      });
      await svc.clearConsentFlags();
      expect(svc.acknowledgedPolicyVersion, isNull);
      expect(svc.acknowledgedAt, isNull);
    });

    test('hasAcknowledgedCurrentPolicy is false after clear', () async {
      final svc = await makeService();
      await svc.acknowledgePrivacyPolicy();
      await svc.clearConsentFlags();
      expect(svc.hasAcknowledgedCurrentPolicy, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ConsentSummary
  // ---------------------------------------------------------------------------
  group('PrivacyConsentService — summary', () {
    test('summary reflects current state', () async {
      final svc = await makeService();
      await svc.setAnalyticsOptIn(true);
      await svc.acknowledgePrivacyPolicy();
      final s = svc.summary;
      expect(s.analyticsOptIn, isTrue);
      expect(s.hasAcknowledgedCurrentPolicy, isTrue);
      expect(s.currentPolicyVersion,
          PrivacyConsentService.currentPolicyVersion);
      expect(s.acknowledgedPolicyVersion,
          PrivacyConsentService.currentPolicyVersion);
      expect(s.acknowledgedAt, isNotNull);
    });

    test('summary reflects empty state by default', () async {
      final svc = await makeService();
      final s = svc.summary;
      expect(s.analyticsOptIn, isFalse);
      expect(s.hasAcknowledgedCurrentPolicy, isFalse);
      expect(s.acknowledgedPolicyVersion, isNull);
      expect(s.acknowledgedAt, isNull);
    });
  });
}
