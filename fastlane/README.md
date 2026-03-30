fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios testflight_internal

```sh
[bundle exec] fastlane ios testflight_internal
```

Build and upload a build for internal TestFlight testers

Wrapper script:

```sh
./scripts/testflight_internal.sh
```

### ios testflight_external

```sh
[bundle exec] fastlane ios testflight_external
```

Build and upload a build for external TestFlight testers

Wrapper script:

```sh
./scripts/testflight_external.sh
```

External tester notes are read from:

```sh
fastlane/what_to_test/en-US.txt
```

This file is uploaded as one English "What to Test" text for TestFlight.

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload an App Store release, copying English release notes to all locales

Wrapper script:

```sh
./scripts/release.sh
```

### ios release_existing_build

```sh
[bundle exec] fastlane ios release_existing_build
```

Submit an already uploaded TestFlight build for App Store release

Set `SUBMIT_FOR_REVIEW=1` to submit directly for review.
Set `AUTO_RELEASE=1` to automatically release after approval.
Optionally set `APP_STORE_BUILD_NUMBER=150` to target a specific processed build.

Wrapper script:

```sh
./scripts/release_existing_build.sh --submit --build 150
./scripts/release_existing_build.sh --submit --auto-release --build 150
```

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
