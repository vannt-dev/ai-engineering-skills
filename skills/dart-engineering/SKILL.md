---
name: dart-engineering
description: Implement, debug, review, refactor, and test Dart and Flutter projects using repository-compatible SDK, package, null-safety, async, widget, and testing practices. Use when affected files include pubspec.yaml, .dart source, generated Dart code, or Flutter or Dart tests.
---

# Dart Engineering

Preserve null-safety soundness and widget lifecycle correctness across Dart packages and Flutter apps.

## Inspect First

- Read project instructions and inspect `pubspec.yaml`, `pubspec.lock`, the Dart SDK and Flutter version constraints, `analysis_options.yaml`, and any `build_runner` or code-generation setup.
- Determine whether the target is a Flutter app, a plain Dart package, or a plugin with native platform channels before editing; widget lifecycle and platform boundaries differ across these.
- Identify the project's existing state-management approach (Provider, Riverpod, Bloc, GetX, or similar) and generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`) that must not be hand-edited.

## Engineering Guidance

- Preserve null-safety soundness. Do not add `!` non-null assertions, `late` without a real invariant, or `dynamic` to silence the analyzer without addressing the underlying nullability.
- Keep `build` methods free of side effects; avoid widening `setState`/rebuild scope beyond what changed.
- Dispose every controller, `StreamSubscription`, `AnimationController`, timer, and focus node created by a `State` in its `dispose` method.
- Never use a `BuildContext` across an `await` without checking `mounted` (or the ref/ScaffoldMessenger equivalent) immediately before use.
- Keep asynchronous work cancellation-aware: cancelled or disposed widgets and use cases must not update state or dereference a disposed controller.
- Do not hand-edit generated files; change the source model or annotation and rerun the project's code generator instead.
- Preserve the project's existing state-management pattern rather than introducing a second one for the same concern.
- Treat platform-channel method names, argument shapes, and native (Android/iOS/desktop) counterparts as part of the affected surface when changing a platform channel.

## Verification

Prefer repository scripts. Otherwise run `dart analyze` (or `flutter analyze`) and the project's test command (`dart test` or `flutter test`) on the narrowest affected package before broader suites. Run `dart format` or other mutating tools only within authorized scope.

Do not change the Dart SDK constraint, Flutter version, or `pubspec.yaml` dependencies unless the task requires it.
