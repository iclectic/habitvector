# ADR-005: Local Recommendation Engine with Interface

**Status**: Accepted  
**Date**: Phase 0

## Context

The product requires personalised habit recommendations. Options considered:
1. Cloud ML model (e.g. Vertex AI, SageMaker)
2. On-device neural network (TFLite)
3. Local interpretable model (logistic regression, Bayesian updating, rules)

## Decision

Implement a local interpretable model behind a `RecommendationEngine` interface in the application layer.

Phase 2 delivers deterministic cold-start rules. Phase 3 adds an interpretable personalised scoring layer (Bayesian-updated completion probability per context segment) that replaces the cold-start rules after sufficient observations exist.

The interface allows future replacement with a TFLite model or a cloud API without changing the presentation layer.

## Rationale

- Cloud ML requires connectivity and data exfiltration — incompatible with offline-first and privacy requirements.
- TFLite neural networks are not explainable at the individual prediction level.
- Logistic regression and Bayesian updating produce feature weights that can be directly presented to the user as "why this recommendation".
- Data volumes per user (typically <5,000 observations) do not justify the complexity of a neural network.

## Consequences

- All recommendation logic lives in the application layer, not in widgets or repositories.
- The engine must be testable with seeded deterministic inputs.
- Model version metadata is stored in the database alongside recommendations.
- The engine has a documented fallback path for sparse data and missing context.
