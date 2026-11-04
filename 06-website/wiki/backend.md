# Backend

Serverless stack on AWS: **Cognito** for auth, **S3** for data, **DynamoDB** for metadata, **API Gateway + Lambda** for the REST API. Deployed with SAM.

---

## Architecture

```
  Browser / App
       │  idToken (JWT)
       ▼
 ┌───────────────┐      ┌──────────────┐
 │  API Gateway  │─────▶│   Lambda     │
 │  (HTTP API)   │      │   handlers   │
 └───────┬───────┘      └──────┬───────┘
         │ Cognito              │
         │ authorizer           ▼
   ┌─────▼─────┐          ┌────────────┐
   │  Cognito  │          │ DynamoDB   │
   │ User Pool │          │  signals   │
   └───────────┘          └────────────┘
                                │
   Browser ──── presigned PUT ──┼──▶ S3 walkeeg-data-prod
                                │
                      S3 event ─┴──▶ process Lambda
```

---

## Deploy

### Prerequisites

- AWS CLI configured
- [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- Node.js 20+
- IAM permissions for `walkeeg-deploy` — see `07-backend/IAM.md`

### Commands

```bash
cd 07-backend
npm install
sam build

sam deploy --guided     # first deployment
sam deploy              # subsequent (uses samconfig.toml)
```

### Stack outputs

```bash
aws cloudformation describe-stacks \
  --stack-name walkeeg-backend \
  --query "Stacks[0].Outputs" \
  --region us-west-2
```

Copy each output into the front end:

| Output | Goes into |
|---|---|
| `UserPoolId` | `config.js` / `app_config.dart` |
| `UserPoolClientId` | same |
| `IdentityPoolId` | same |
| `DataBucketName` | same |
| `ApiEndpoint` | same |

---

## API

All routes require `Authorization: Bearer <idToken>` — except `OPTIONS`.

| Method | Path | Description |
|---|---|---|
| `GET` | `/me` | Current user profile |
| `GET` | `/signals` | List the caller's signals |
| `POST` | `/signals` | Register metadata after an S3 upload |
| `GET` | `/signals/{id}` | Detail + presigned download URL |
| `DELETE` | `/signals/{id}` | Delete metadata and the S3 object |

### POST /signals

```json
{
  "name": "Resting State",
  "description": "eyes closed, 2 min",
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

### Unauthenticated behaviour

```bash
curl -i https://<api-id>.execute-api.us-west-2.amazonaws.com/prod/me
＃ HTTP/2 401
＃ {"message":"Unauthorized"}
```

A healthy deployment answers **401 within about a second**. If you get `502`, `503` or a timeout instead, the Lambda or authorizer is broken — not the credentials.

---

## S3 layout

```
s3://walkeeg-data-prod/
└── {identity-pool-sub}/
    └── signals/
        ├── 2026-07-28_resting.csv
        └── 2026-07-29_motor_part0001.csv
```

> **Note the two different `sub` values.** The S3 prefix uses the **Cognito Identity Pool** subject (`cognito-identity.amazonaws.com:sub`). The DynamoDB `userId` uses the **User Pool** `sub` from the JWT. They are not interchangeable.

---

## Upload flow

1. App authenticates → receives `idToken` and temporary AWS credentials from the Identity Pool
2. App `PUT`s the CSV directly to S3 under its identity prefix
3. App calls `POST /signals` with the resulting `s3Key`
4. Lambda writes the metadata row to DynamoDB
5. An S3 event invokes `process.js` for any `.csv` object (currently a skeleton for future FFT work)

Direct-to-S3 upload keeps large files off Lambda — the function only ever handles JSON metadata.

---

## Local development

```bash
sam local start-api
```

Serves the routes locally; Cognito authorisation still requires real tokens unless you stub the authorizer.

---

## Files

```
07-backend/
├── template.yaml        SAM template — pools, bucket, table, API
├── samconfig.toml       deploy parameters
├── IAM.md               permissions needed to deploy
├── src/handlers/        Lambda entry points
└── events/              sample payloads for `sam local invoke`
```

---

## Related

- [Data Portal](https://www.walkeeg.com/app/) — the web front end that consumes this API
- Full integration checklist: `07-backend/INTEGRATION.md`
