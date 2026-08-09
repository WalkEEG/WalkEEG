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

## Cloud Backend

After deploying `07-backend` with SAM, copy stack outputs into [`assets/js/config.js`](assets/js/config.js) (template: [`config.example.js`](assets/js/config.example.js)). The Data Portal at `/app/` will then use Cognito login, S3 direct upload, and the REST API instead of demo mode.

See [`../../07-backend/INTEGRATION.md`](../../07-backend/INTEGRATION.md) for the full checklist.

## Data Portal (`/app/`)

After deploying [`07-backend`](../07-backend), copy stack outputs into [`assets/js/config.js`](assets/js/config.js) (see [`config.example.js`](assets/js/config.example.js)). Integration checklist: [`07-backend/INTEGRATION.md`](../07-backend/INTEGRATION.md).

When Cognito is configured, the portal uses real auth, S3 direct upload, and the REST API instead of demo mode.

### Cloud backend config

After deploying `07-backend`, copy stack outputs into `assets/js/config.js`. See [`../../07-backend/INTEGRATION.md`](../../07-backend/INTEGRATION.md).

After deploying the backend (`07-backend`), copy stack outputs into `assets/js/config.js` (see `config.example.js`). When configured, `/app/` uses Cognito + S3 + API instead of demo mode.

See [`../../07-backend/INTEGRATION.md`](../../07-backend/INTEGRATION.md) for the full checklist.

After deploying the backend (`07-backend`), copy stack outputs into `assets/js/config.js`. See [`../07-backend/INTEGRATION.md`](../07-backend/INTEGRATION.md).
