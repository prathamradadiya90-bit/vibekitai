# ADR 0005: Riverpod Architecture, State Hygiene & Codegen Decision

## Status
Accepted

## Context
VibeKit AI utilizes Riverpod 2.x for client-side state management across generation pipelines, quota tracking, billing synchronization, and streak management.
A key architectural question in modern Flutter development is whether to adopt annotation-based code generation (`riverpod_generator` + `build_runner`) or pure manual Riverpod 2.x (`Notifier` / `AsyncNotifier` / `StateNotifier`).

## Decision
We select **Pure Manual Riverpod 2.x with Strict Hygiene Conventions** and decline `riverpod_generator` code generation:

1. **Compilation Speed & Developer Velocity:**
   - Avoiding `build_runner` eliminates multi-minute code generation steps during development, CI builds, and PR validation.
   - Hot reload and hot restart remain instantaneous.

2. **Clean Architecture Boundary:**
   - Domain layer models, use cases, and entities remain pure Dart without dependencies on codegen annotations or generated partial files (`.g.dart`).
   - Feature controllers inherit from standard `StateNotifier<T>` or `AsyncNotifier<T>`.

3. **Strict Hygiene Rules Enforced:**
   - **`autoDispose` on Ephemeral Providers:** All generation screen controllers and temporary form state providers use `.autoDispose` so that state, listeners, and resources are immediately garbage collected when the user navigates away.
   - **Granular `.select()` in Presentation:** UI widgets listening to multi-property states (like `QuotaModel`) must use `ref.watch(provider.select((s) => s.property))` to avoid unnecessary widget rebuilds.
   - **No Cross-Provider Internal Mutation:** Providers expose immutable states; dependencies between providers are resolved strictly through read-only reads or unidirectional event dispatch.

## Consequences
- **Positive:** Zero generated file noise in git diffs (`*.g.dart`), faster CI test execution.
- **Positive:** Clear, transparent Dart code that any Flutter engineer can read and debug without familiarity with macro-like annotations.
- **Trade-off:** Requires writing standard `Provider` and `StateNotifierProvider` declarations manually (which is less than 50 lines of clean code across the entire app).
