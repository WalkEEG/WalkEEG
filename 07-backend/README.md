# WalkEEG Backend — AWS deployment example

> **This directory is one deployment, not the platform.** It assumes AWS
> (Cognito, S3, DynamoDB, API Gateway, Lambda). If you are not on AWS, skip it.
>
> The signal processing it calls lives in [`../algorithms/`](../algorithms) and has
> no cloud dependency — take that directory on its own.

AWS SAM stack: Cognito auth, S3 data storage, DynamoDB metadata, API Gateway + Lambda.

## Where the algorithms actually are

`src/handlers/process.js` is deliberately thin: it reads S3, calls the shared
statistics module, writes results. All numeric work belongs in
[`../algorithms/`](../algorithms), which is standard-library Python with no AWS
imports, so the same functions run in a Lambda, a cron script, or a notebook.

Rules of thumb:

- **Real-time** processing never comes through here — live display needs a round
trip that doesn't exist. That runs on the device.
- **Offline batch** analysis is what this stack is for.
- Before changing a filter or a metric, change the contract in
  [`docs/algorithms/`](../docs/algorithms) first, then the implementation, then
the tests in [`algorithms/python/conformance_test.py`](../algorithms/python/conformance_test.py).

## Prerequisites

- AWS CLI configured (`aws configure`)
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- Node.js 20+
- `walkeeg-deploy` IAM permissions — see [IAM.md](IAM.md)

## Deploy

```bash
cd 07-backend
npm install
sam build
sam deploy --guided   # first time
# or
sam deploy            # uses samconfig.toml
```

## Stack Outputs

After deploy, copy outputs into frontend/mobile config:

```bash
aws cloudformation describe-stacks \
  --stack-name walkeeg-backend \
  --query "Stacks[0].Outputs" \
  --region us-west-2
```

| Output | Used in |
|--------|---------|
| `UserPoolId` | `config.js`, Flutter `app_config.dart` |
| `UserPoolClientId` | same |
| `IdentityPoolId` | same |
| `DataBucketName` | same |
| `ApiEndpoint` | same |

## API Endpoints

All routes require `Authorization: Bearer <idToken>` except OPTIONS.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/me` | Current user profile |
| GET | `/signals` | List user's signals |
| POST | `/signals` | Register signal metadata after S3 upload |
| GET | `/signals/{id}` | Signal detail + presigned download URL |
| DELETE | `/signals/{id}` | Delete metadata + S3 object |

### POST /signals body

```json
{
  "name": "Resting State",
  "description": "optional",
  "s3Key": "{identityId}/signals/2026-07-28_resting.csv",
  "identityId": "us-west-2:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "fileName": "2026-07-28_resting.csv",
  "fileSize": 123456,
  "channels": "8",
  "sampleRate": "2000 Hz",
  "duration": "120s",
  "segments": []
}
```

## S3 Layout

```
s3://walkeeg-data-prod/
└── {identity-pool-sub}/
    └── signals/
        ├── 2026-07-28_resting.csv
        └── 2026-07-29_motor_part0001.csv
```

> **Note:** S3 prefix uses Cognito **Identity Pool** id (`cognito-identity.amazonaws.com:sub`), not User Pool `sub`. DynamoDB `userId` uses User Pool `sub` from JWT.

## Local Testing

```bash
sam local start-api
```

## Process Lambda

`src/handlers/process.js` is triggered on `.csv` uploads. It is a skeleton: the
handler shape exists, the numeric pipeline does not.

When filling it in, implement the algorithms in [`../algorithms/`](../algorithms)
against the contracts below — do not write a second copy of the math here:

- [`docs/algorithms/eeg-pipeline.md`](../docs/algorithms/eeg-pipeline.md)
- [`docs/algorithms/emg-pipeline.md`](../docs/algorithms/emg-pipeline.md)
- [`docs/algorithms/conformance.md`](../docs/algorithms/conformance.md)

## Integration

See [INTEGRATION.md](INTEGRATION.md) for web/mobile config and end-to-end test checklist.
