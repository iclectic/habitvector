# ADR-004: Additive-Only Database Migrations

**Status**: Accepted  
**Date**: Phase 0

## Context

Existing users have habit and log data in schema version 1. Any migration that modifies existing table structure risks data loss.

## Decision

All schema changes to existing tables use `ALTER TABLE ADD COLUMN` with defaults only. No existing columns are renamed, dropped, or changed in type. New tables are created fresh in `onUpgrade`.

The database file name `habit_flow.sqlite` is never changed.

Schema version history:
- v1: `habits`, `habit_logs`
- v2: + `daily_check_ins`, `work_shifts`, `habit_versions`, `adaptive_recommendations`, `habit_experiments`, `experiment_observations`, `model_metadata`, `analytics_events`

## Consequences

- Existing user data is preserved through all upgrades.
- Migration tests must verify that a v1 database can be opened at v2 without errors and that all original habits and logs are still readable.
- The export/import version string must be bumped when new exportable entities are added, with backward-compatible import for the previous version.
