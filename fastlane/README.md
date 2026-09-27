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

### ios upload_whats_new

```sh
[bundle exec] fastlane ios upload_whats_new
```

Upload What's New to the editable App Store version; pass localized:true to use localized files

### ios upload_descriptions

```sh
[bundle exec] fastlane ios upload_descriptions
```

Upload localized app descriptions to the existing editable App Store version

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload an App Store release; pass localized:true to use localized release notes

### ios release_existing_build

```sh
[bundle exec] fastlane ios release_existing_build
```

Submit an existing TestFlight build; pass localized:true to use localized release notes

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
