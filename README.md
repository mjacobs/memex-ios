# Memex for iOS

A native SwiftUI client for [Memex](https://github.com/mjacobs/memex).

The first release covers the everyday loop:

- connect to a Memex server with an origin-bound device key stored in Keychain;
- read and filter Feed notes, including Markdown and agent traces;
- capture text or an AAC voice recording; and
- review open, done, and dropped tasks and toggle open/done status.

Chat, approvals, routine runs, image/link capture, and sharing are later work.
See [the design](docs/design.md) and
[implementation plan](docs/implementation-plan.md) for the boundaries.

## Configure

On first launch, enter the HTTPS URL for a Memex deployment and one of its
device keys. **Save & Test Connection** checks the public health endpoint before
sending the candidate key to the authenticated notes endpoint.

The key is never stored in source or ordinary preferences. Changing the server
origin requires a key entered for that origin.

## Build

Requires Xcode 26 or newer.

```sh
xcodebuild -project Memex.xcodeproj \
  -scheme Memex \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

To compile the app and unit-test bundle without booting a Simulator:

```sh
xcodebuild -project Memex.xcodeproj \
  -scheme Memex \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Run tests against an already-booted Simulator by replacing `SIMULATOR_UDID`:

```sh
xcodebuild -project Memex.xcodeproj \
  -scheme Memex \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  test
```

Debug builds can launch with `MEMEX_PREVIEW_MODE=1` to show deterministic Feed
and Tasks fixtures without storing a server key. Production builds ignore this
environment variable.
