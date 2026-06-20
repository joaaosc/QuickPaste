# AGENTS.md

## Project Identity

This is a Swift/macOS project.

The project must be treated as a macOS-first app, not as an iOS app stretched onto macOS.

Prioritize:
- native Apple frameworks;
- clear modular architecture;
- deterministic behavior where possible;
- maintainable Swift code;
- small, reviewable changes;
- build/test validation after meaningful edits.

Do not change the product scope without explicitly explaining the tradeoff.

## Global Rules

Before editing code:

1. Read the relevant project files.
2. Identify the current architecture and entry points.
3. Check existing ADRs, documentation, and project conventions.
4. State the intended change briefly.
5. List files likely to be modified, created, or removed.

After editing code:

1. Run the most relevant build/test validation.
2. Report exactly what changed.
3. Report files modified, created, or removed.
4. Report build/test results.
5. Report remaining risks.

Prefer small changes over large rewrites.

Do not introduce third-party dependencies unless they are clearly justified and approved by the project direction.

## Skill Routing

Use the installed skills according to task type.

### `swift-architecture-skill`

Use for:
- project structure;
- modularization;
- feature boundaries;
- domain models;
- services;
- repositories;
- ViewModels;
- dependency injection;
- ADRs;
- refactoring plans;
- separation between UI, state, domain, and infrastructure.

Expected behavior:
- propose clear module boundaries;
- avoid logic inside SwiftUI views;
- avoid global state when dependency injection is feasible;
- keep features removable;
- explain architectural tradeoffs.

### `swiftui-pro`

Use for:
- SwiftUI views;
- macOS UI;
- AppKit bridges;
- menus;
- commands;
- toolbars;
- sidebars;
- inspectors;
- Settings;
- windows;
- accessibility;
- previews;
- Human Interface Guidelines review.

Expected behavior:
- treat macOS as the primary platform;
- avoid iOS-style stretched layouts;
- use native macOS patterns;
- preserve keyboard, window, menu, and focus behavior;
- consider accessibility and Dynamic Type where relevant;
- use AppKit only when SwiftUI is insufficient.

### `swift-testing-pro`

Use for:
- Swift Testing;
- XCTest;
- test architecture;
- fixtures;
- mocks/fakes;
- snapshot/golden-style tests when appropriate;
- smoke tests;
- regression tests;
- build/test workflows.

Expected behavior:
- prefer deterministic tests;
- avoid fragile UI tests unless necessary;
- test business logic outside the UI;
- validate important regressions;
- keep tests proportional to the change.

### `apple-ai-and-models`

Use for:
- Apple Intelligence;
- Foundation Models;
- Core ML;
- CoreAI;
- Vision;
- NaturalLanguage;
- App Intents;
- Siri/Shortcuts integration;
- semantic indexing;
- Spotlight integration;
- on-device model workflows;
- private-cloud AI tradeoffs;
- model conversion;
- AI evaluation.

Do not use this skill artificially.

If the task does not involve AI, models, Vision, App Intents, semantic indexing, or related Apple intelligence features, explicitly state that this skill is not relevant.

Expected behavior:
- prefer Apple-native AI/ML frameworks;
- separate input, preprocessing, inference, post-processing, UI, and evaluation;
- define privacy boundaries;
- define fallback behavior when AI/model features are unavailable;
- avoid placing prompts or model calls directly inside SwiftUI views;
- propose evaluation strategy for AI behavior.

## MCP Routing

Use MCP tools when they improve correctness or validation.

### Apple Docs MCP

Use when:
- working with Apple beta APIs;
- using unfamiliar SwiftUI/AppKit APIs;
- using Foundation Models, Core ML/CoreAI, Vision, App Intents, or other Apple frameworks;
- checking API availability;
- checking framework behavior;
- resolving uncertainty about official Apple patterns.

Expected behavior:
- verify uncertain APIs against official Apple documentation;
- avoid guessing signatures for new APIs;
- prefer current Apple guidance over memory.

### XcodeBuildMCP

Use when:
- discovering projects, schemes, targets, or destinations;
- building the macOS app;
- running tests;
- diagnosing compiler errors;
- validating changes after implementation.

Expected behavior:
- prefer XcodeBuildMCP over hand-written `xcodebuild` commands when available;
- report scheme, destination, and result;
- do not claim validation succeeded unless build/test actually ran.

## Architecture Policy

Keep the project modular.

Prefer this separation:

- `App`: app entry point, scene setup, app-level wiring.
- `Features`: user-facing feature modules.
- `Core`: domain models, pure logic, shared abstractions.
- `Services`: system integrations and side effects.
- `Infrastructure`: file system, persistence, external APIs, adapters.
- `UI`: reusable views and visual components, if the project uses a shared UI layer.
- `Tests`: unit tests, integration tests, fixtures, and smoke tests.

SwiftUI views should not own heavy business logic.

ViewModels may coordinate UI state, but domain rules should live outside the ViewModel when they are reusable or testable.

Services should usually be accessed through protocols when doing so improves testability.

Avoid premature abstraction. Add protocols and layers when they support testing, feature boundaries, or platform separation.

## macOS UX Policy

The app must feel native to macOS.

Prefer:
- `WindowGroup` for primary windows;
- `Settings` for app preferences;
- `Commands` for menu bar actions;
- `MenuBarExtra` for menu bar apps;
- `NavigationSplitView` for sidebar-based layouts;
- inspectors for contextual detail when appropriate;
- toolbars for primary actions;
- keyboard shortcuts for frequent commands;
- AppKit bridges for macOS-specific behavior that SwiftUI cannot express well.

Avoid:
- full-screen mobile-style navigation;
- oversized touch-first controls without macOS rationale;
- hidden primary commands;
- modal-heavy flows;
- business logic embedded in views;
- visual changes that reduce clarity or accessibility.

## Apple AI / Model Policy

Before implementing any AI/model feature, answer:

1. Can the feature be solved deterministically without AI?
2. Can Vision, NaturalLanguage, Core ML/CoreAI, or Foundation Models solve it locally?
3. Is a custom model required?
4. What data leaves the device, if any?
5. What happens when the model/API is unavailable?
6. How will output quality be evaluated?
7. What parts are deterministic and testable?
8. What parts require manual or fixture-based evaluation?

AI output should be editable or inspectable when it may be imperfect.

Long-running model work must expose progress, cancellation, and error states.

## Testing Policy

Every meaningful code change should include at least one of:

- build validation;
- unit tests;
- integration tests;
- smoke test;
- explicit explanation of why tests were not added.

Prefer testing pure logic first.

For SwiftUI, avoid brittle tests of layout details unless necessary.

For AI/model features, test:
- preprocessing;
- post-processing;
- fallback paths;
- model availability handling;
- deterministic fixtures;
- output schema validation where applicable.

## Documentation and ADR Policy

Use ADRs for decisions that affect:

- architecture;
- persistence;
- public data models;
- framework choices;
- AI/model strategy;
- major UI structure;
- non-trivial tradeoffs.

ADRs should be short and concrete.

Recommended ADR format:

```md
# ADR NNNN: Title

## Status

Accepted / Proposed / Superseded

## Context

What problem forced this decision?

## Decision

What are we choosing?

## Consequences

What improves?
What gets worse?
What must be watched?
```

Do not create ADRs for trivial implementation details.

## Workflow for Agents

For analysis-only tasks:

1. Read relevant files.
2. Identify applicable skills.
3. Identify applicable MCPs.
4. Produce diagnosis.
5. Suggest next steps.
6. Do not edit files.

For implementation tasks:

1. Read relevant files.
2. Identify applicable skills.
3. Identify applicable MCPs.
4. Produce short implementation plan.
5. List files to modify/create/remove.
6. Implement in small steps.
7. Run build/test validation.
8. Report final result.

For debugging tasks:

1. Reproduce or inspect the failure.
2. Identify likely cause.
3. Make the smallest safe fix.
4. Run targeted validation.
5. Explain the root cause and the fix.

For UI tasks:

1. Review current macOS behavior.
2. Check native macOS patterns.
3. Use `swiftui-pro`.
4. Use Apple Docs MCP for uncertain APIs.
5. Validate build.
6. Report accessibility and UX tradeoffs.

For AI/model tasks:

1. Use `apple-ai-and-models`.
2. Check whether AI is actually needed.
3. Prefer Apple-native frameworks.
4. Define privacy boundary.
5. Define fallback behavior.
6. Define evaluation strategy.
7. Validate build/tests where possible.

## Final Report Format

At the end of implementation work, report:

```md
## Summary

What changed.

## Skills Used

- skill name: why it was relevant

## MCPs Used

- MCP name: why it was used

## Files Changed

- Modified:
- Created:
- Removed:

## Validation

- Build:
- Tests:
- Known failures:

## Tradeoffs

What improved.
What became more complex.
What remains risky.

## Next Step

One recommended next step.
```

## Anti-patterns

Avoid:

- rewriting the whole app without need;
- adding dependencies before checking Apple-native options;
- mixing UI and domain logic;
- placing model calls directly in SwiftUI views;
- using AI where deterministic logic is better;
- skipping build/test validation after code edits;
- claiming APIs exist without checking documentation;
- making iOS-first UI decisions in a macOS app;
- editing unrelated files;
- creating broad abstractions with no immediate use;
- changing scope silently.

## Handoff Requirement

After every meaningful implementation session, update `HANDOFF.md`.

The update must include:

- current OCR step;
- files modified/created/removed;
- validation result;
- known blockers;
- next recommended step.

Do not leave `HANDOFF.md` stale after code changes.
