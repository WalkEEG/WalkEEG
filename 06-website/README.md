# WalkEEG Website

This directory contains the [www.walkeeg.com](https://www.walkeeg.com) website.

## Pages

- **`/`** — Homepage. Open-source WalkEEG project introduction.
- **`/app/`** — Data Portal SPA. User registration, EEG signal upload, visualization, and download.

## Tech Stack

- Vanilla HTML/CSS/JS (no framework)
- Chart.js for signal visualization
- Hosted on S3 + CloudFront

## Deployment

Any push to the `06-website/` directory automatically deploys via GitHub Actions.
