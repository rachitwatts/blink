## What & why

<!-- Briefly describe the change and the motivation. -->

## Testing

- [ ] `./scripts/run-tests.sh unit` passes locally
- [ ] **Every bug fix has a regression test** that fails before the fix and passes after
- [ ] New/changed logic in `Blink/Services`, `Blink/Models`, or `Shared` has unit tests (the coverage ratchet gates this layer at the floor in `scripts/check-coverage.sh`)
- [ ] No test creates real UI or mutates real user state — tests touching `AppState`/`Settings`/timers inherit `BlinkTestCase` (isolated `UserDefaults` suite, in-memory analytics, suppressed windows)
- [ ] No assertions on incidental UI copy (display-name/emoji strings) or unseeded-RNG ratios

## Notes

<!-- Anything reviewers should know: trade-offs, follow-ups, screenshots. -->
