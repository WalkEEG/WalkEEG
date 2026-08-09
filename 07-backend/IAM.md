# IAM Permissions for `walkeeg-deploy`

Attach the following permissions to the `walkeeg-deploy` IAM user (or deployment role) before running `sam deploy`.

## Required Service Permissions

| Service | Actions | Purpose |
|---------|---------|---------|
| Cognito Identity Provider | `cognito-idp:*` | Create User Pool, App Client |
| Cognito Identity | `cognito-identity:*` | Create Identity Pool, role attachment |
| Lambda | `lambda:*` | API + process functions |
| API Gateway | `apigateway:*` | HTTP API, routes, authorizers |
| DynamoDB | `dynamodb:*` | Signals metadata table |
| S3 | `s3:CreateBucket`, `s3:PutBucket*`, `s3:GetBucket*`, `s3:DeleteBucket*` | Data bucket `walkeeg-data-prod` |
| CloudFormation | `cloudformation:*` | SAM stack deploy |
| IAM | `iam:CreateRole`, `iam:DeleteRole`, `iam:AttachRolePolicy`, `iam:DetachRolePolicy`, `iam:PutRolePolicy`, `iam:DeleteRolePolicy`, `iam:GetRole`, `iam:PassRole` | Lambda + Cognito roles |
| Logs | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` | Lambda logging |

## Example Inline Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:*",
        "cognito-identity:*",
        "lambda:*",
        "apigateway:*",
        "dynamodb:*",
        "s3:CreateBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketCors",
        "s3:PutBucketVersioning",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucket*",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "cloudformation:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Post-Deploy: Authenticated User S3 Access

End users receive scoped S3 access via the Cognito Identity Pool authenticated role (created by SAM). They can only read/write objects under:

```
s3://walkeeg-data-prod/{identity-pool-sub}/signals/*
```

This is separate from `walkeeg-deploy` permissions.
