# FLwatch Website

Static site for the FLwatch iOS/watchOS app, built with Jekyll and optimized for GitHub Pages at https://poml88.github.io/FLwatch.

## Local development

```bash
bundle install
bundle exec jekyll serve --baseurl "" --watch
```

Then open http://localhost:4000/FLwatch/ (or / depending on config).

## Update content

- Replace `assets/icon.png` with your actual 1024×1024 app icon (PNG).
- Edit language pages in `/content/*.md` (English is `content/en.md`).
- Update SEO metadata in `_config.yml` (title, description, app links).