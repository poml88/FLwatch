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

### ios testflight_external

```sh
[bundle exec] fastlane ios testflight_external
```

Build and upload a build for external TestFlight testers

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload an App Store release, copying English release notes to all locales

### ios release_existing_build

```sh
[bundle exec] fastlane ios release_existing_build
```

Submit an already uploaded TestFlight build for App Store release

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
