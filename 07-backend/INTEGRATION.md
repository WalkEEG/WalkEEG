# WalkEEG Cloud Integration Checklist

After deploying `07-backend` with SAM, configure web and mobile clients.

## 1. Deploy Backend

```bash
cd 07-backend
npm install
sam build
sam deploy
```

Copy stack outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name walkeeg-backend \
  --query "Stacks[0].Outputs" \
  --region us-west-2
```

## 2. Configure Web (`06-website`)

Edit [`06-website/assets/js/config.js`](../06-website/assets/js/config.js):

```javascript
window.WALKEEG_CONFIG = {
  region: 'us-west-2',
  userPoolId: '<UserPoolId>',
  userPoolClientId: '<UserPoolClientId>',
  identityPoolId: '<IdentityPoolId>',
  dataBucket: '<DataBucketName>',
  apiBaseUrl: '<ApiEndpoint>',
};
```

Redeploy website (push to `06-website/` or manual S3 sync).

When `config.js` has real values, `/app/` automatically disables demo mode and uses Cognito + S3 + API.

## 3. Configure Flutter (`05-Flutter program`)

Edit [`05-Flutter program/lib/config/app_config.dart`](../05-Flutter%20program/lib/config/app_config.dart) with the same values.

```bash
cd "05-Flutter program"
flutter pub get
flutter run
```

## 4. End-to-End Test

### Web

1. Open `https://www.walkeeg.com/app/` (or local static server)
2. Register / sign in
3. Upload a `.csv` file
4. Verify it appears in **My Signals**
5. Download and delete work

### Mobile

1. Connect WalkEEG device via BLE
2. Tap **Start recording** — CSV segments written locally (~30 s each)
3. Tap **Stop recording**
4. Sign in (cloud icon)
5. Tap **Sync** — segments upload to S3, metadata registered via API
6. Confirm recording appears on web portal

## 5. S3 Path Convention

```
s3://walkeeg-data-prod/{identity-pool-id}/signals/{date}_{name}.csv
```

- **S3 prefix** = Cognito Identity Pool id (from `GetId`)
- **DynamoDB userId** = Cognito User Pool `sub` (from JWT)

## 6. API Quick Reference

| Method | Path | Auth |
|--------|------|------|
| GET | `/me` | Bearer idToken |
| GET | `/signals` | Bearer idToken |
| POST | `/signals` | Bearer idToken |
| GET | `/signals/{id}` | Bearer idToken |
| DELETE | `/signals/{id}` | Bearer idToken |

## 7. Troubleshooting

| Issue | Fix |
|-------|-----|
| CORS error on API | Check `WebsiteOrigin` parameter in SAM deploy |
| S3 upload 403 | Verify Identity Pool role; key must start with `{identityId}/signals/` |
| Login fails | Confirm email verified; check User Pool app client auth flows |
| Demo mode still active | `config.js` still has `REPLACE_*` placeholders |
| Flutter sync fails | Fill `app_config.dart`; sign in before sync |

## 8. IAM for Deploy User

See [IAM.md](IAM.md) for `walkeeg-deploy` permissions.
