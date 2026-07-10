# HabitVector Adaptive Lab — Privacy and Threat Model

## Principles

1. **Local-first by default.** All habit data, context check-ins, shift schedules, recommendations, and experiments are stored on-device in SQLite. Nothing leaves the device unless explicitly authorised.
2. **Explicit consent for every external action.** Calendar access, optional analytics, and any optional AI coach require separate, reversible consent.
3. **Data minimisation.** Only fields required for the stated function are collected. Free-text habit names, journal notes, and precise locations are never sent externally.
4. **No secret keys in the client.** Firebase configuration identifiers are not secrets. OAuth tokens, signing keys, and any analytics API keys must not appear in source control.
5. **Transparent redaction.** Before any optional external request, the application displays the exact categories of data being shared.

## Data Categories

| Category | Storage | External? | Sensitive? |
|----------|---------|-----------|------------|
| Habit definitions (title, schedule, colour) | SQLite, local | Never (opt-in backup only) | Low |
| Habit completion logs | SQLite, local | Never | Low |
| Daily context check-ins (energy, workload) | SQLite, local | Never | Medium |
| Shift schedules (type, label, times) | SQLite, local | Never | Low |
| Adaptive recommendations | SQLite, local | Never | Low |
| Experiment results | SQLite, local | Never | Medium |
| Recovery metrics | SQLite, local | Never | Low |
| Firebase Auth identity (UID, email) | Firebase | Identity only | Medium |
| Analytics events (anonymous, aggregated) | Local + optional remote | Opt-in, no habit content | Low |
| Optional AI coach context | Redacted summary only | Explicit per-request consent | Medium |

## Threat Model

### Threat 1: Unauthorised access to on-device SQLite data

**Risk**: Another app or a malicious actor with device access reads the SQLite database.  
**Mitigation**: The database is stored in the application's private documents directory. On Android, this is protected by the OS sandbox. On iOS, the application sandbox provides equivalent protection. Full disk encryption (Android FBE, iOS Data Protection) is enabled by default on all supported devices.  
**Limitation**: If the device is unlocked and compromised, all application data is readable. SQLite-level encryption (e.g. SQLCipher) would mitigate this for sensitive fields. This is documented as a future option. The current implementation does not apply additional encryption beyond OS-level data protection.  
**Honest statement**: We do not claim the database is fully encrypted. We claim it is protected by the OS sandbox and device encryption, consistent with all local-only apps on these platforms.

### Threat 2: Firebase Auth token theft

**Risk**: An attacker obtains a Firebase ID token.  
**Mitigation**: Firebase Auth tokens are short-lived (one hour) and are refreshed automatically. They are not stored in plaintext in SharedPreferences. The application uses the Firebase SDK's secure token storage.  
**Limitation**: If the device is rooted or jailbroken, token extraction may be possible. This is a platform limitation.

### Threat 3: Secrets committed to source control

**Risk**: API keys or signing credentials appear in the repository.  
**Mitigation**: Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) contain app identifiers, not secrets. No OAuth client secrets, signing keystores, or analytics keys are committed. `.gitignore` excludes these files.

### Threat 4: Analytics data identifying individuals

**Risk**: Optional aggregate analytics inadvertently identifies specific users.  
**Mitigation**: Analytics events use anonymous session identifiers that rotate on each app install. No habit names, check-in text, or precise timestamps are included. Events are documented in `docs/analytics-specification.md`.

### Threat 5: AI coach request exposing private data

**Risk**: User sends personally identifiable habit or journal content to an external language model.  
**Mitigation**: Before any external AI request, the application displays the exact categories (not values) of data being shared and requires explicit per-request consent. Free-text content is never sent without additional explicit confirmation. The AI coach is an optional module, disabled by default.

## Data Retention and Deletion

- All local data can be deleted via Settings → Privacy → Delete All Data.
- Firebase Auth identity can be deleted via Settings → Account → Delete Account.
- Analytics opt-out is available in Settings → Privacy → Analytics.
- Deleted data is not recoverable by the application (standard SQLite DELETE, not soft-delete, for user-initiated deletion).

## Export and Import Security

- Exported JSON contains all habit and log data in plaintext. Users are informed of this before export.
- Import validation rejects files with structural errors, mismatched versions, and duplicate logs.
- Imported data is not executed as code.

## Calendar Access

- Calendar integration is disabled by default.
- When enabled, the application requests read-only access to selected calendars only.
- Users choose which calendars and event categories may be used.
- Calendar event titles and descriptions are not stored; only event type, duration category, and date are used.

## Future Considerations

- SQLCipher for field-level encryption of sensitive context data
- Secure enclave storage for auth tokens on supported devices
- Differential privacy for aggregate analytics if the user base scales
