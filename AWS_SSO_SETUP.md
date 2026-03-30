# AWS SSO Profile Setup & Lambda Invocation Guide

## Prerequisites

- AWS CLI v2 installed ([download](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- Access granted to the AWS account via AWS IAM Identity Center (SSO)
- SSO start URL and region provided by your administrator

---

## 1. Configure the SSO Profile

Run the interactive SSO configuration wizard:

```bash
aws configure sso
```

You will be prompted for the following values:

| Prompt | Example value | Notes |
|---|---|---|
| SSO session name | `my-sso` | A name for the reusable SSO session |
| SSO start URL | `https://my-company.awsapps.com/start` | Provided by your admin |
| SSO region | `us-east-1` | The region where IAM Identity Center is hosted |
| SSO registration scopes | `sso:account:access` | Press Enter to accept the default |

After entering the SSO details the browser opens automatically for login. Once authenticated, the CLI lists the accounts and roles available to you:

```
There are 2 AWS accounts available to you.
> MyCompany-Dev, dev-account@example.com (123456789012)
  MyCompany-Prod, prod-account@example.com (987654321098)
```

Select the account and role, then finish the configuration:

| Prompt | Example value |
|---|---|
| CLI default client Region | `us-east-1` |
| CLI default output format | `json` |
| CLI profile name | `dev` |

This creates a named profile called `dev` (or whatever name you chose) in `~/.aws/config`.

---

## 2. Log In

Before running any commands, authenticate with SSO:

```bash
aws sso login --profile dev
```

A browser window opens. Complete the login and return to the terminal. Your credentials are cached for the duration of the session (typically 8 hours).

To verify the login worked:

```bash
aws sts get-caller-identity --profile dev
```

Expected output:

```json
{
    "UserId": "AROAEXAMPLEID:jane.doe@example.com",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/DeveloperRole/jane.doe@example.com"
}
```

---

## 3. Set a Default Profile (Optional)

To avoid typing `--profile dev` on every command, export it as an environment variable:

```bash
export AWS_PROFILE=dev
```

Add this line to your `~/.bashrc` or `~/.zshrc` to make it permanent.

---

## 4. Invoke a Lambda Function

Replace `{Your-Env-Profile}` with your actual profile name (e.g. `dev`, `staging`, `prod`).

### Run a Laravel Artisan migration

```bash
aws lambda invoke \
  --function-name pt-solution-api-test-artisan \
  --cli-binary-format raw-in-base64-out \
  --payload '{"cli": "migrate --force"}' \
  --region eu-central-1 \
  --profile {Your-Env-Profile} \
  /tmp/pt-migrate.json 2>&1 && echo "--- RESPONSE ---" && cat /tmp/pt-migrate.json
```

### General invocation pattern

```bash
aws lambda invoke \
  --function-name {function-name} \
  --cli-binary-format raw-in-base64-out \
  --payload '{your-json-payload}' \
  --region eu-central-1 \
  --profile {Your-Env-Profile} \
  /tmp/response.json 2>&1 && echo "--- RESPONSE ---" && cat /tmp/response.json
```

- `--function-name` — the Lambda function name or its full ARN
- `--payload` — JSON input sent to the function
- `--cli-binary-format raw-in-base64-out` — required with AWS CLI v2 to pass plain JSON payloads
- `--region` — AWS region where the function is deployed
- `/tmp/response.json` — file where the function response is written; printed to terminal after invocation

### Asynchronous invocation (fire and forget)

```bash
aws lambda invoke \
  --function-name {function-name} \
  --invocation-type Event \
  --cli-binary-format raw-in-base64-out \
  --payload '{your-json-payload}' \
  --region eu-central-1 \
  --profile {Your-Env-Profile} \
  /tmp/response.json
```

Returns HTTP 202 immediately without waiting for execution to finish.

---

## 5. Useful Lambda Commands

```bash
# List all functions in the account
aws lambda list-functions --profile dev

# Get function configuration
aws lambda get-function-configuration \
  --function-name my-function \
  --profile dev

# Tail the most recent logs after invocation
aws logs tail /aws/lambda/my-function \
  --follow \
  --profile dev
```

---

## 6. Log Out

When finished, revoke the cached SSO credentials:

```bash
aws sso logout --profile dev
```

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Error loading SSO Token` | Session expired or not logged in | Run `aws sso login --profile dev` |
| `An error occurred (ExpiredTokenException)` | Cached token expired mid-session | Run `aws sso login --profile dev` |
| `ResourceNotFoundException` | Wrong function name or region | Check `--function-name` and `--region` values |
| `AccessDeniedException` | Role lacks Lambda invoke permission | Ask your admin to grant `lambda:InvokeFunction` |
| Browser does not open | Headless environment | Copy the printed URL and open it manually |
