# Localized App Descriptions

Before running `bundle exec fastlane ios upload_descriptions`, add a nonempty
`description.txt` file for every supported locale:

- `de-DE/description.txt`
- `en-GB/description.txt`
- `es-ES/description.txt`
- `fr-FR/description.txt`
- `it/description.txt`
- `ja/description.txt`
- `nl-NL/description.txt`
- `pl/description.txt`
- `ru/description.txt`
- `zh-Hans/description.txt`

Create the new editable app version in App Store Connect first. The lane uploads
only these descriptions; it does not upload a build or screenshots, submit the
version for review, or modify the release-notes metadata directory.
