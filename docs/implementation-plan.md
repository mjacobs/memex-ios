# Memex iOS Core Implementation Plan

**Merge path:** local `main` in the new `memex-ios` repository; no remote exists
yet, so publication is a separate user decision.  
**Reviewer:** Matt, whole-tree review at handoff.  
**Kill criterion:** stop and report if the documented Memex API cannot support
Feed, text/voice capture, or task mutation without a server change, or if the
iOS toolchain cannot produce server-accepted `audio/mp4` data.  
**Size class:** architectural, medium — a new native app with four feature
surfaces and one external API, intentionally excluding the Android app’s
secondary workflows.

## 1. Establish a buildable project

- Add a minimal Xcode project with app and unit-test targets.
- Target iOS 17, Swift 6, and the `com.memex.ios` bundle identifier.
- Add the microphone purpose string and generated asset catalog.
- Add a scheme suitable for command-line build and test.
- Verify a clean simulator SDK build before feature work.

## 2. Implement the contract boundary

- Add Codable note, capture, task, trace, response, and error models.
- Add normalized server configuration and credential-origin types.
- Implement a small async `MemexAPI` protocol and `URLSession` client.
- Attach authorization only to exact-origin requests and refuse cross-origin
  redirects.
- Add deterministic URL-protocol tests for success and structured failures.

## 3. Add connection storage and setup

- Implement `UserDefaults` preferences behind a protocol.
- Implement a Keychain store behind a protocol, including stored origin.
- Implement anonymous health and authenticated note probes.
- Build first-launch Settings with save, test, clear-key, and error states.
- Verify that failed tests do not replace a working connection.

## 4. Wire the app shell

- Add the root dependency graph using SwiftUI environment injection.
- Add independent Feed and Tasks navigation stacks in a two-tab `TabView`.
- Route Settings from Feed and capture through one item-driven sheet.
- Add fixture services so every screen can preview without a server.

## 5. Build Feed and note detail

- Implement Feed loading, pull-to-refresh, kind/tag filtering, and retry.
- Add note rows with stable identities and compact metadata.
- Implement note detail, native basic Markdown, transcript, and trace replay.
- Cover loaded, empty, loading, and error states with previews and tests.

## 6. Add text capture

- Implement the capture store and shared sheet shell.
- Add text validation, submission, success, and structured failure states.
- Refresh Feed after success while preventing duplicate submissions.
- Test payload source and cancellation behavior.

## 7. Add voice capture

- Implement microphone permission, `AVAudioSession`, AAC `.m4a` recording,
  metering, and temporary-file cleanup.
- Upload raw audio and poll its capture record with cancellation and timeout.
- Show recording, uploading, processing, enriched, failed, and timeout states.
- Test polling with a deterministic clock and fake API.

## 8. Build Tasks

- Implement status loading and segmented filtering.
- Add optimistic open/done mutation with rollback on failure.
- Add read-only dropped-task presentation and source-note metadata.
- Cover refresh, empty, error, successful mutation, and rollback in tests.

## 9. Verify the core

- Run the full unit-test target and a clean simulator build.
- Inspect all compiler warnings and enable strict concurrency checking.
- Once the user boots a Simulator, launch the app and inspect the accessibility
  tree and screenshots for the setup, Feed, capture, detail, and Tasks flows.
- Record any live-server checks separately; never persist or print a real key.
- Hand off the exact commands, verified behavior, and any open risk, including
  the repository having no remote.
