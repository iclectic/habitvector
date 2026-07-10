# HabitVector Adaptive Lab — Innovation Thesis

## 1. The Problem with Streak-First Habit Trackers

The dominant design paradigm in consumer habit tracking — streaks, daily checklists, completion charts — optimises for one user profile: someone with a predictable daily schedule and high baseline consistency.

For this profile, streaks are motivating. For everyone else, they are a punishment mechanism dressed up as a reward.

A nurse who works three twelve-hour night shifts followed by four days off does not have "days". They have shifts, recovery periods, handovers, and transitions. A standard daily habit tracker assigns them a failure every night they are on shift and did not complete a habit that requires daylight, quiet, or energy they do not have.

This is not a niche concern. The majority of working adults in healthcare, logistics, hospitality, emergency services, and care work operate on shift patterns. Students alternate between intense exam periods and lighter terms. Parents have unpredictable days determined by dependents, not by personal planning.

The streak model punishes exactly the people who could benefit most from habit support.

## 2. The Needs of People with Irregular Schedules

Research in behavioural science identifies several factors that determine habit formation and maintenance:

- **Implementation intentions** (when, where, how) reduce reliance on willpower.
- **Contextual cues** are more reliable than time-based reminders when context varies.
- **Flexible scheduling** (e.g. x times per week rather than every day) increases adherence for people with variable schedules.
- **Recovery after missing** is a stronger predictor of long-term adherence than initial streak length.

None of these are well-supported by mainstream habit trackers. HabitVector Adaptive Lab addresses all four.

## 3. Why Personalised Experiments Are Different from Generic Advice

Generic habit advice (e.g. "attach your habit to an existing routine") is population-level. It works for the average person, which means it does not work optimally for any specific person.

Personal experiments allow individuals to test whether a specific strategy works for them. This is the n-of-1 methodology — a single-subject experimental design used in clinical research to personalise medical treatment — applied to behavioural self-improvement.

The key difference from advice:

- Generic advice: "Morning habits have higher completion rates."
- Personal experiment result: "Over 21 days, you completed this habit on 11 of 11 mornings-before-work but only 3 of 10 evenings-after-shift. A morning window is more effective for you specifically."

The second statement is truthful, qualified, and actionable. It does not claim to be universally true. It describes what happened for this individual over a defined period.

## 4. Why Local Explainable Adaptation Was Selected

The alternative — sending data to a cloud model and receiving a recommendation — has three problems for this product:

1. **Privacy**: Habit data is personal behavioural data. Sending it to an external service requires explicit user trust and informed consent. Many users in this target audience (healthcare workers, carers) are appropriately cautious about data sharing.

2. **Explainability**: Opaque models cannot be audited. If the application recommends a change to a user's schedule, that user deserves to understand exactly why. A neural network cannot provide this. Logistic regression, Bayesian updating, and rule-based systems can.

3. **Reliability**: The application must work offline. Healthcare workers and carers often work in areas with poor connectivity.

The chosen approach — local computation on structured features, with explainable scoring — is technically appropriate for the data quantities involved (typically a few hundred to low thousands of observations per user), does not require a cloud dependency, and can provide full audit trails.

## 5. What Is Technically Original in This Implementation

- **Context-aware minimum viable habit system**: Three versions of every habit (minimum, standard, stretch) with context-matched selection and honest differentiation of their value.
- **Shift-aware planning with explicit user approval**: The system suggests rescheduling but never silently rearranges habits.
- **N-of-1 experiment engine with statistical qualification**: Completion rates, absolute and relative differences, and credible intervals, with responsible uncertainty language built in.
- **Recovery Intelligence**: Recovery time, recovery success rate, and resilience trend — not as a replacement for streaks but as a complement.
- **Friction Map**: Visual pattern identification by day of week, shift type, available time, and energy, shown only when data is sufficient.
- **Explainability-first recommendation results**: Every recommendation includes factors used, factors missing, confidence level, and a correction path.

## 6. What Remains an Unproven Hypothesis

The following claims are design intentions, not demonstrated outcomes:

- That showing the minimum viable version of a habit increases long-term adherence compared to showing no alternatives.
- That the friction map helps users identify actionable patterns rather than increasing anxiety.
- That the n-of-1 experiment format is usable by non-researchers.
- That recovery framing reduces shame and increases re-engagement after missing a habit.
- That local explainable models produce better recommendation acceptance rates than opaque cloud models.

These hypotheses will be evaluated in the pilot described in `docs/pilot-plan.md`.

## 7. How Real-World Impact Will Be Evaluated

See `docs/pilot-plan.md` for the detailed pilot methodology.

Key metrics:
- Recommendation acceptance rate (target: >50% over 30 days)
- 7-day, 30-day, and 90-day retention relative to a baseline cohort
- Self-reported usefulness score at 14 and 30 days
- Completion rate change before and after implementing a recommendation
- Recovery rate (completion within 2 days of a miss) over time
- Experiment completion rate (percentage of started experiments that reach the minimum sample)

No impact figures from this evaluation will be published until real pilot participants have provided real data.
