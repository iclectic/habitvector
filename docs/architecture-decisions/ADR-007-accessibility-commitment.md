# ADR-007 — Accessibility Commitment

**Status**: Accepted  
**Date**: 2024-07  
**Authors**: HabitVector Engineering

---

## Context

HabitVector is a daily habit-tracking tool. Users interact with it at least
once per day, often in quick sessions. The app must be usable by people who
rely on assistive technology — particularly screen readers (TalkBack on Android,
VoiceOver on iOS) — without degrading the experience for sighted users.

Phase 5 introduced a formal accessibility audit of all interactive widgets.
This ADR documents the decisions made and the standards the codebase commits to
going forward.

---

## Decision

### 1. WCAG 2.1 Level AA as the baseline

All interactive and informational UI components target
[WCAG 2.1 Level AA](https://www.w3.org/TR/WCAG21/) compliance. Where Flutter's
rendering model makes full AA compliance impractical, we document the
limitation and provide the best achievable approximation.

### 2. Semantic labels on all interactive widgets

Every widget that triggers an action or conveys dynamic state must have an
explicit `Semantics` label. Minimum requirements:

| Widget type | Requirement |
|---|---|
| `HabitTile` | Label = `"<habit name>, <status>. Double tap to open details."` |
| Toggle button | Label = `"Mark <habit name> as done / not done"`, `checked` state set |
| Skip button | Label = `"Skip <habit name>"` |
| `SummaryCard` | Label = `"<title>: <value> <subtitle>"`, `excludeSemantics: true` |
| `SwitchListTile` (privacy) | Label includes current toggle state |
| Destructive actions | Label describes the action explicitly |

### 3. `excludeSemantics` on composite widgets

Widgets that compose multiple text/icon children into a single logical unit
(e.g. `SummaryCard`, toggle circles) use `excludeSemantics: true` on the
wrapper so screen readers announce the composite label once, not each child
separately.

### 4. Minimum tap target size: 44 × 44 dp

All tappable elements must meet the minimum 44 × 44 dp tap target recommended
by both Apple HIG and Material Design. `IconButton` widgets use
`visualDensity: VisualDensity.compact` only where the surrounding padding
already satisfies this requirement. Touch targets are never reduced below
this threshold.

### 5. Tooltip text mirrors the semantic label

`tooltip` strings on `IconButton` widgets must match the `Semantics` label.
This ensures consistent discovery whether the user is using a pointing device,
a touch screen, or a screen reader.

### 6. Dynamic content uses live region semantics

Status indicators that update without user interaction (e.g. the "completed"
state of a habit tile after a background sync) must be wrapped with
`Semantics(liveRegion: true)` so screen readers announce the change.
This is implemented on the habit-completion toggle state.

### 7. Colour contrast

All text and icon colours in `AppTheme` use pairs that meet WCAG AA contrast
ratios (≥ 4.5:1 for normal text, ≥ 3:1 for large text and UI components).
Opacity-based dimming (e.g. `withOpacity(0.6)`) is acceptable only when the
resulting contrast ratio is verified. Unverified opacity combinations are
documented as known gaps.

### 8. No information conveyed by colour alone

Status (completed / skipped / pending) is indicated by both colour **and**
icon/text. A user with complete colour blindness must be able to distinguish
all habit states without colour information.

---

## Consequences

- **Positive**: Screen-reader users can navigate and complete all primary
  workflows (viewing habits, marking complete, skipping, opening details)
  without visual feedback.
- **Positive**: Explicit semantic labels prevent ambiguous announcements like
  "button" or "icon" with no context.
- **Negative**: Adding `Semantics` wrappers increases widget tree depth. In
  practice the impact on frame rendering is negligible for lists of ≤ 50 items.
- **Ongoing obligation**: Any new interactive widget added to the codebase must
  include a `Semantics` annotation before merging. This is verified by code
  review, not automated tooling (as of this ADR).

---

## Alternatives Considered

**Flutter's default semantics only**: Rejected. Flutter infers semantics from
widget types, but inferred labels for `GestureDetector`, `AnimatedContainer`,
and custom `IconButton` wrappers are often empty or ambiguous.

**Automated accessibility testing with `flutter_test` semantics API**:
Noted as a future addition. The `SemanticsController` in `flutter_test`
can verify labels in widget tests. This will be added in Phase 6 when the
widget test suite is expanded.
