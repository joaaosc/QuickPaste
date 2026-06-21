# CLAUDE.md — QuickPaste Formula-to-LaTeX Crash Fix

## Mission

Fix one bug only:

`EXC_BAD_ACCESS` / `swift_retain` crash when clicking **Converter fórmula para LaTeX** on an inline image in QuickPaste.

The app appears to crash before Core AI records inference events.

This is likely an object lifetime / non-Sendable / AppKit-capture issue, not a model-conversion issue.

## Token policy

Be concise.

Do not write long plans.

Do not re-explain previous milestones.

Do not redesign QuickPaste.

Do not discuss product roadmap.

Do not add unrelated UI.

Do not introduce optional features.

Maximum normal response: 25 lines.

Prefer code inspection and small diffs over explanation.

## Current architecture facts

QuickPaste is a macOS-first SwiftUI/AppKit menu bar utility.

Important existing layers:

* `NoteTextEditor` / `NSTextView`: inline images as `NSTextAttachment`
* `EditorView`: SwiftUI wrapper
* `EditorModel`: `@MainActor`, orchestrates OCR/formula jobs
* `FormulaConverting`: existing seam
* `Editor/OCR/`: existing Vision OCR pipeline
* `Editor/FormulaRecognition/`: new Core AI formula runtime

The existing Vision OCR pipeline, paste behavior, translation, hotkeys, Settings, RTFD persistence, LSUIElement behavior, and sandbox rules must remain unchanged.

## Hard constraints

Do not commit.

Do not modify the Core AI model.

Do not modify `LatexOCR.aimodel`.

Do not retrain.

Do not reconvert.

Do not change tokenizer semantics.

Do not change greedy decoder semantics.

Do not change image preprocessing semantics unless the crash proves the payload boundary is unsafe.

Do not add Finder Services, Quick Actions, Share Extension, or Finder Extension.

Do not add or restore:

* Open in Preview
* output Settings
* copy/both output modes
* extra menu actions
* new UI polish

Do not commit runtime artifacts.

Do not commit `.aimodel`.

## Required first action

Run:

```bash
git status --short
```

Report what is dirty.

Do not reset or discard changes without explicit approval.

## Crash description

Trigger:

1. Paste or insert inline image.
2. Right-click image.
3. Choose `Converter fórmula para LaTeX`.
4. App crashes in `libswiftCore.dylib swift_retain`.
5. Xcode Core AI Report shows `0 events`.

Implication:

The path probably crashes before `AIModel` / `InferenceFunction.run`, or while crossing into the async formula job.

## Primary suspicion

Unsafe object crosses an async/concurrent boundary.

Search for any of these being captured, stored, or sent into a `Task`, actor, queue, async job, or closure:

* `NSImage`
* `NSTextAttachment`
* `NSTextView`
* `NSMenuItem`
* `NSBitmapImageRep`
* `NSPasteboardItem`
* `InferenceValue`
* `NDArray`
* `NDArray.View`
* Core AI runtime objects
* AppKit objects in general

## Debug path to inspect

Audit this exact path:

```text
NSMenuItem action
→ NoteTextEditor image hit-test / attachment extraction
→ callback closure
→ EditorView callback
→ EditorModel enqueue formula job
→ OCR/formula queue
→ FormulaConverting.latex(from:)
→ CoreAIFormulaConverter
→ CoreAI model loader
→ encoder call
→ decoder call
```

Add minimal temporary logs if needed:

```text
[Formula] menu action clicked
[Formula] stable image snapshot created
[Formula] enqueueFormula called
[Formula] formula job started
[Formula] converter.latex started
[Formula] before model load
[Formula] before encoder
[Formula] before decoder
```

If the crash happens before a log line, identify that boundary.

Remove noisy logs after fixing, or keep only useful debug-level logs if the project already has logging conventions.

## Required fix strategy

At the menu-click boundary, create a stable independent image payload.

Allowed safe payloads:

1. `Data` encoded from the inline image, then decoded later into `CGImage`.
2. A new `CGImage` rendered into an independent bitmap context.
3. A standalone immutable image wrapper that does not retain `NSTextAttachment`, `NSImage`, `NSTextView`, or image reps.

Preferred:

```text
MainActor / AppKit boundary:
NSTextAttachment or NSImage
→ render/copy to independent CGImage or PNG/TIFF Data
→ enqueue only that copied payload
```

Never enqueue:

* `NSImage`
* `NSTextAttachment`
* `NSTextView`
* `NSMenuItem`
* `NSBitmapImageRep`
* any AppKit view/editor object

The queued formula job must retain only the copied payload.

## Core AI output safety

Verify the ported Core AI code from LatexOCRlab respects the noncopyable/Core AI lifetime rules.

Requirements:

* Do not store `InferenceValue`.
* Do not store `NDArray` views.
* Do not return Core AI view buffers.
* Consume `InferenceValue` immediately.
* Copy output floats/ints immediately into Swift arrays.
* Keep `AIModel`, `InferenceFunction`, and runtime objects inside the adapter/actor.
* No Core AI tensor object should escape into SwiftUI/AppKit/editor layers.

If the crash happens inside Core AI output handling, compare with the working LatexOCRlab implementation, especially the `InferenceValue` consuming/copy behavior.

## Core AI linkage check

Verify but do not over-focus on this unless build/runtime proves it:

* `CoreAI.framework` must be weak/optional-linked because QuickPaste deploys to macOS 26.5.
* Core AI code must be behind `@available(macOS 27, *)`.
* QuickPaste must launch and work on macOS 26.5.
* If Core AI is unavailable, formula menu item must be hidden or disabled gracefully.

## Asset path check

Do not change asset strategy unless directly related to the crash.

Expected runtime asset policy:

* Bundle tokenizer JSON only.
* Do not bundle or commit `LatexOCR.aimodel`.
* Load `LatexOCR.aimodel` from Application Support.
* Missing asset must show a clear message and never crash.

## Tests to add or update

Add focused tests only.

Useful tests:

* menu/image extraction creates an independent payload
* formula job does not store AppKit objects
* fake `FormulaConverting` can run asynchronously from the queued payload
* no-formula message still works
* existing Vision OCR tests still pass
* asset missing path still does not crash

Do not add UI tests unless strictly necessary.

## Commands

Run focused tests first.

Then run the normal project build/test command used by QuickPaste.

At minimum:

```bash
xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

Run the project’s test command if it is already documented.

Do not spend tokens repeatedly running the entire suite unless code outside the formula path changed.

## LLDB evidence

If Xcode is stopped at the crash, ask the user for:

```lldb
bt
thread backtrace all
```

Do not speculate endlessly without stack frames.

If stack frames show one of these, focus there:

* `NoteTextEditor`
* `EditorView`
* `EditorModel`
* `FormulaConverting`
* `CoreAIFormulaConverter`
* `CoreAIModel`
* `InferenceValue`
* `NDArray`

## Allowed files to modify

Prefer only files directly related to the formula feature:

* `Editor/NoteTextEditor.swift`
* `Editor/EditorView.swift`
* `Editor/EditorModel.swift`
* `Editor/OCR/OCRServices.swift` only if the seam requires it
* `Editor/FormulaRecognition/**`
* formula-related tests
* `HANDOFF.md`

Do not modify unrelated Settings, Translation, HotKey, AppDelegate, persistence, or window-layer files.

## HANDOFF.md discipline

Update `HANDOFF.md` briefly:

1. after confirming dirty state
2. after identifying likely crash boundary
3. after implementing the fix
4. after tests/build
5. before final report

Keep entries concise.

## Final report format

Return only:

```text
Root cause:
Changed files:
Tests/build:
Manual verification:
Remaining risks:
Commit status:
```

Do not commit automatically.

Wait for user approval before committing.

