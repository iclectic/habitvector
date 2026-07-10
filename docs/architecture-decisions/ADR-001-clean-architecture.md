# ADR-001: Clean Architecture Layer Separation

**Status**: Accepted  
**Date**: Phase 0

## Context

The application requires testable domain logic, swappable data implementations, and a clear separation between UI and business rules.

## Decision

Maintain strict four-layer architecture: Domain → Application → Data → Presentation.

- Domain entities and repository interfaces have no Flutter or Drift imports.
- Application use cases depend on domain interfaces only.
- Data repositories implement domain interfaces.
- Presentation depends on application layer via Riverpod providers.

## Consequences

- Domain and application layers can be tested without Flutter or SQLite.
- The recommendation engine, experiment analysis, and recovery analysis are all application-layer services, not widgets.
- Adding a new data backend (e.g. cloud sync) requires implementing a new repository, not changing the application layer.
