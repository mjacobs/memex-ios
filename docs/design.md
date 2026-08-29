# Memex iOS Core Design

Status: approved for implementation  
Date: 2026-08-29

## Outcome

The first iOS release makes the two everyday Memex loops native on iPhone:
capture a thought, then read or complete what Memex produced from it. It is a
small core, not a screen-for-screen port of the Android application.

The app will:

- connect to a user-selected Memex server with a bearer key stored in Keychain;
- show the note feed and note details, including basic Markdown and agent trace;
- capture text synchronously;
- record and upload voice, then poll until enrichment succeeds or fails; and
- show open, done, or dropped tasks and toggle open/done status.

The app will live in its own `memex-ios` repository and target iOS 17 or later.

## Not in the first release

Chat, approvals, routine runs, link and image capture, research controls, a
Share Extension, offline caching, push notifications, and editing or deleting
notes are deliberately deferred. The API and navigation boundaries leave room
for those features without making the core depend on them.

## User experience

### First launch and settings

When no usable server URL has been saved, the app opens Settings. The user enters
an HTTPS server URL and a device key, then taps **Save & Test Connection**.
The app checks `/health` without credentials before sending the candidate key to
the authenticated notes endpoint. A successful test installs the new connection
for the rest of the app.

Changing the server URL does not reuse a key saved for another origin. The
Keychain record stores the normalized origin alongside the key, matching the
Android client’s security boundary.

### Feed

Feed is the first tab. It loads the newest 50 notes, supports pull-to-refresh,
and offers compact kind and tag filters. Each row shows kind, date, summary,
body preview, tags, and task count. Selecting a row opens a detail screen with
the full body, transcript when present, and an expandable trace replay.

Loading, empty, authentication, connection, and retry states are visible in the
screen rather than represented by a blank list.

### Capture

A prominent add button on Feed presents one item-driven sheet with Text and
Voice modes.

Text capture sends the text with `source: "ios"`. On success the sheet closes
and Feed refreshes.

Voice capture requests microphone permission immediately before recording,
records AAC audio into an `.m4a` file, shows elapsed time and input level, and
uploads the raw file as `audio/mp4` with `X-Memex-Source: ios`. The sheet then
polls the capture record until it is enriched or failed. Dismissing the sheet
cancels polling and cleans up its temporary recording.

### Tasks

Tasks is the second tab. A segmented control selects Open, Done, or Dropped.
Tapping an open task marks it done; tapping a done task reopens it. The row
updates immediately and rolls back with an error message if the server rejects
the change. Dropped tasks are read-only in this first release.

## App structure

`MemexApp` owns one `AppEnvironment`, which contains preferences, credential
storage, and the current API client. SwiftUI receives that environment once at
the root. Feature state remains in small `@Observable`, main-actor stores owned
by Feed, Capture, Tasks, and Settings views.

The two tabs each own a `NavigationStack`. Feed routes to note detail and
presents capture with `sheet(item:)`. Settings is a Feed toolbar destination,
not a third tab.

The source tree is grouped by responsibility:

```text
Memex/
  App/          root wiring, tabs, shared environment
  Core/         API models, API client, errors, Keychain, preferences
  Features/
    Feed/
    Capture/
    Tasks/
    Settings/
  UI/           shared badges, Markdown, trace replay, state views
```

There are no third-party runtime packages. Foundation handles JSON and HTTP,
Security handles the Keychain, AVFAudio handles recording, and SwiftUI renders
the interface.

## Networking and data

An `actor` API client owns a configured ephemeral `URLSession`. Every API call
constructs its URL relative to a validated base URL and attaches the bearer key
only when the request origin exactly matches the key’s stored origin. Redirects
to another origin must not receive the authorization header.

Codable response envelopes mirror `docs/contracts.md` in the server repository.
Dates remain strings at the wire boundary and are parsed by a shared formatter
for display. Trace arguments and results use a small recursive JSON value type so
the UI can pretty-print arbitrary tool payloads.

HTTP failures decode the server’s `{error: {code, message}}` envelope when
available. The UI gets a typed error with a safe user-facing message; bearer
keys and authorization headers are never logged.

## Security and privacy

- The bearer key is a generic-password Keychain item marked
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- The non-secret server URL lives in `UserDefaults`.
- The key is sent only to its recorded HTTPS origin.
- `/health` is tested anonymously before candidate credentials are transmitted.
- Microphone access is explained through `NSMicrophoneUsageDescription` and
  requested only when the user starts voice capture.
- Recordings live in the temporary directory, are excluded from backup by
  location, and are removed after success, failure, cancellation, or app restart
  cleanup.

## State and failure behavior

Each feature store exposes one explicit state: idle, loading, loaded, or failed,
plus only the feature-specific mutation state it needs. SwiftUI `.task` starts
view-bound loads. Cancellation is a normal outcome and is not shown as an error.

Voice polling uses a one-second interval and a 30-attempt limit, matching the
Android client. A timeout keeps the successful capture ID visible and tells the
user that processing may still finish on the server; it does not report the
upload itself as failed.

## Accessibility and presentation

The interface uses native controls, Dynamic Type, system colors, and SF Symbols.
Interactive icons have labels, status is conveyed by text as well as color, and
recording controls expose their state and elapsed time. Previews cover loaded,
empty, loading, and error states without live services.

## Verification

Unit tests cover:

- model decoding against representative server payloads;
- URL and origin validation, including redirect protection;
- structured API errors;
- Feed loading and filtering;
- text capture and voice polling outcomes;
- optimistic task updates and rollback; and
- Settings connection installation without exposing the key.

The app must build with strict concurrency checking. Simulator verification
covers first launch, mocked populated Feed, text capture, recording permission
handling, task toggle, empty states, and accessibility labels. Live-server smoke
testing is optional and must never embed a real device key in source or test
arguments.

## Facts this design depends on that live outside the code

These checks were run before this document was written.

1. The local toolchain is Xcode 26.6, Swift 6.3.3, with an iOS 26.5 simulator
   SDK. Proven by:

   ```sh
   xcodebuild -version
   xcrun --sdk iphonesimulator --show-sdk-version
   swift --version
   ```

2. No Simulator is currently booted. Interactive verification therefore needs
   the user to boot one when implementation reaches that step. Proven by:

   ```sh
   xcrun simctl list devices booted
   ```

3. The server contract provides synchronous text capture, asynchronous raw
   audio capture, capture polling, notes, tasks, and structured bearer-authenticated
   errors. Proven by:

   ```sh
   rg -n '^\\| `(POST /api/v1/capture|POST /api/v1/capture/audio|GET /api/v1/captures|GET /api/v1/notes|GET /api/v1/tasks|PATCH /api/v1/tasks|GET /health)' docs/contracts.md
   rg -n 'Authorization: Bearer|Errors:' docs/contracts.md
   ```

   Run in `/Users/mj/dev/projects/memex`.

4. The Android client binds encrypted credentials to their server origin, polls
   voice capture, and rolls task mutations back after server failure. Proven by:

   ```sh
   rg -n 'class EncryptedSecureTokenStorage|stopRecordingAndSubmit|toggleTaskCompletion' app/src/main/java/com/memex/android/{data/security/SecureTokenStorage.kt,ui/capture/CaptureViewModel.kt,ui/tasks/TasksViewModel.kt}
   ```

   Run in `/Users/mj/dev/projects/memex-android`.

5. Apple documents SwiftUI Observation for iOS 17+, Keychain Services for small
   secrets, asynchronous `URLSession`, and `AVAudioRecorder` with explicit record
   permission. References:

   - <https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app>
   - <https://developer.apple.com/documentation/security/keychain-services>
   - <https://developer.apple.com/documentation/foundation/urlsession>
   - <https://developer.apple.com/documentation/avfaudio/avaudiorecorder>
   - <https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)>
