# WalkEEG Backend

AWS SAM stack: Cognito auth, S3 data storage, DynamoDB metadata, API Gateway + Lambda.

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

`src/handlers/process.js` is triggered on `.csv` uploads. Currently a skeleton for future FFT processing.

## Integration

See [INTEGRATION.md](INTEGRATION.md) for web/mobile config and end-to-end test checklist.
