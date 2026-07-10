# ADR-006 — Experiment Privacy and Data Retention

**Status**: Accepted  
**Date**: 2024-07  
**Authors**: HabitVector Engineering

---

## Context

Phase 4 introduced N-of-1 experiments that record daily observations over weeks
or months. Each `ExperimentObservation` contains:

- Which intervention the user was assigned to (A or B)
- Whether the habit was completed
- Optional references to a `DailyCheckIn` (energy, workload)
- Optional reference to a `WorkShift`

This data is more sensitive than raw habit logs because:

1. It reveals structured *behavioural variation* over time (e.g. the user
   performs better on morning schedules).
2. Cross-referencing with check-in energy/workload data could surface health
   patterns the user did not intend to share.
3. Experiment conclusions are stored as `resultSummary` text that may describe
   personal patterns in plain language.

---

## Decision

### 1. All experiment data is stored locally only

`HabitExperiment` and `ExperimentObservation` records are persisted exclusively
in the on-device SQLite database (`habit_flow.sqlite`). They are **never**
transmitted to any external service unless the user explicitly triggers an
export.

### 2. Export includes a clear disclosure

The existing data-export flow in `ExportImportUseCases` must display the
following notice before sharing the file:

> "Your export contains experiment observations, including which intervention
> was applied each day and whether the habit was completed. This data is in
> plaintext JSON. Share only with people or services you trust."

This disclosure is tracked by a pre-export consent flag (to be implemented as
part of the export flow in a future iteration).

### 3. Deletion is complete and immediate

When the user triggers **Settings → Privacy → Delete All Data**:

- All `HabitExperiment` rows are deleted.
- All `ExperimentObservation` rows are deleted (via `deleteObservationsForExperiment`
  called for each experiment, or via `CASCADE` on the FK if supported by the
  schema).
- No soft-delete mechanism is used. SQLite `DELETE` is immediate.

Cancelling an experiment preserves observations **only while the experiment
record exists**. Once the experiment row is deleted, all observations are
unreachable.

### 4. Conclusion language is non-causal

`ExperimentAnalyser` conclusions use observational language ("associated with",
"tended to", "in this data") to avoid overstating the scientific validity of
personal N-of-1 results. This is enforced by the analyser and verified by
tests in `experiment_analyser_test.dart`.

### 5. Confounding notes are user-generated text

The `confoundingNotes` field on `HabitExperiment` contains free-text entered
by the user. It is:

- Never analysed or sent externally.
- Included in JSON exports alongside the experiment.
- Deletable with the rest of the experiment data.

---

## Consequences

- **Positive**: Users can run structured experiments without any data leaving
  the device, consistent with the local-first principle in `ADR-005`.
- **Positive**: The non-causal language policy prevents the app from making
  overconfident health claims.
- **Negative**: Without server-side storage, experiment data cannot be
  recovered if the device is lost. Users are responsible for their own backups.
- **Neutral**: The export disclosure requirement adds a future work item to
  the export flow.

---

## Alternatives Considered

**Server-side experiment storage**: Rejected. Would require explicit consent
for each user, GDPR compliance infrastructure, and cloud architecture — out of
scope for a local-first portfolio project.

**Differential privacy on observations**: Noted as a future option in
`privacy-and-threat-model.md`. Not implemented because the data never leaves
the device, making differential privacy redundant for the current threat model.
