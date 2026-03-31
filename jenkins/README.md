# Jenkins Setup Guide

This document covers how to configure Jenkins to work with this repository,
enforce the GitOps promotion hierarchy, and deploy to AWS Lambda.

---

## Required Jenkins Plugins

Install all of the following from **Manage Jenkins → Plugins**:

| Plugin | Purpose |
|--------|---------|
| [GitHub Branch Source](https://plugins.jenkins.io/github-branch-source/) | Multibranch pipeline — auto-discovers branches and PRs |
| [Pipeline](https://plugins.jenkins.io/workflow-aggregator/) | Declarative `Jenkinsfile` support |
| [Credentials Binding](https://plugins.jenkins.io/credentials-binding/) | `withCredentials` step |
| [GitHub](https://plugins.jenkins.io/github/) | `githubNotify` step — reports CI status back to GitHub |
| [Amazon Web Services SDK](https://plugins.jenkins.io/aws-java-sdk/) | AWS API support |
| [AWS Credentials](https://plugins.jenkins.io/aws-credentials/) | `AmazonWebServicesCredentialsBinding` |
| [AnsiColor](https://plugins.jenkins.io/ansicolor/) | Coloured console output |
| [Timestamper](https://plugins.jenkins.io/timestamper/) | Timestamps in build logs |
| [Docker Pipeline](https://plugins.jenkins.io/docker-workflow/) | TruffleHog runs in Docker |

---

## Step 1 — Create Jenkins Credentials

Go to **Manage Jenkins → Credentials → (global)**:

| ID | Type | Value |
|----|------|-------|
| `github-token` | Secret Text | GitHub Personal Access Token with `repo` + `read:org` scopes |
| `aws-credentials` | AWS Credentials | Access Key ID + Secret Access Key for the deploy IAM role |

> **Recommended**: Use AWS IAM Roles for the Jenkins agent instead of long-lived keys.
> Grant the agent instance profile permission to assume the deploy role via `sts:AssumeRole`.

---

## Step 2 — Create the Multibranch Pipeline

1. **New Item** → name it `aws-lambda-pipeline` → choose **Multibranch Pipeline**.
2. Under **Branch Sources**, add a **GitHub** source:
   - Credentials: `github-token`
   - Repository: `https://github.com/bahtiti/aws`
3. Under **Behaviors**, add:
   - Discover branches: **All branches**
   - Discover pull requests from forks: enabled
   - Discover pull requests from origin: **Merging the pull request with the current target branch revision**
4. **Build Configuration** → Mode: `by Jenkinsfile` → Script Path: `Jenkinsfile`
5. Scan interval: **1 minute** (or use webhooks — see Step 3).

---

## Step 3 — GitHub Webhook

In GitHub → **Settings → Webhooks → Add webhook**:

```
Payload URL : https://<your-jenkins-host>/github-webhook/
Content type: application/json
Events      : ✔ Push, ✔ Pull requests
Secret      : (optional, configure matching secret in Jenkins)
```

This triggers Jenkins immediately on push and PR events, eliminating polling delay.

---

## Step 4 — Branch Protection Required Status Checks

After the first successful pipeline run, Jenkins registers a GitHub commit status
under the context `Jenkins CI/CD`. Add it as a required status check in GitHub:

**Settings → Branches → Add branch protection rule** for each protected branch:

### `main`
```
✔ Require a pull request before merging
  Required approvals       : 2
  ✔ Dismiss stale reviews when new commits are pushed
  ✔ Require review from Code Owners
  ✔ Require approval of the most recent push

✔ Require status checks to pass before merging
  ✔ Require branches to be up to date
  Required checks          : Jenkins CI/CD

✔ Require signed commits
✔ Require linear history
✔ Include administrators
✔ Restrict who can push  → [release bot / team lead only]
✔ Allow force pushes     : DISABLED
✔ Allow deletions        : DISABLED
```

### `staging`
```
✔ Require a pull request before merging
  Required approvals       : 2
  ✔ Dismiss stale reviews when new commits are pushed

✔ Require status checks: Jenkins CI/CD
✔ Require linear history
✔ Allow force pushes     : DISABLED
✔ Allow deletions        : DISABLED
```

### `develop`
```
✔ Require a pull request before merging
  Required approvals       : 1
  ✔ Dismiss stale reviews when new commits are pushed

✔ Require status checks: Jenkins CI/CD
✔ Allow force pushes     : DISABLED
✔ Allow deletions        : DISABLED
```

---

## Step 5 — Lambda Environment Variables

Set the following as Jenkins environment variables per job (or use a
[`.env` parameter](https://plugins.jenkins.io/envinject/)):

| Variable | Example | Description |
|----------|---------|-------------|
| `LAMBDA_FUNCTION` | `pt-solution-api` | Lambda function name |
| `AWS_REGION` | `eu-central-1` | AWS region |

---

## Step 6 — Lambda Alias Strategy

This pipeline uses [Lambda Aliases](https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html)
to represent environments:

```
Function: pt-solution-api
  Alias: dev      → version N    (deployed on merge to develop)
  Alias: staging  → version M    (deployed on merge to staging)
  Alias: prod     → version P    (deployed on merge to main)
```

Create the aliases once manually:
```bash
aws lambda create-alias --function-name pt-solution-api --name dev     --function-version "\$LATEST"
aws lambda create-alias --function-name pt-solution-api --name staging --function-version "\$LATEST"
aws lambda create-alias --function-name pt-solution-api --name prod    --function-version "\$LATEST"
```

---

## Drift Detection

Create a **separate Jenkins job** (Freestyle or Pipeline) with a cron trigger:

```groovy
// Drift-detection Jenkinsfile snippet
pipeline {
    triggers { cron('H 6 * * *') }  // daily at ~06:00
    stages {
        stage('Drift') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                        terraform init -input=false
                        terraform plan -detailed-exitcode 2>&1 | tee plan.txt
                    '''
                }
            }
        }
    }
    post {
        failure {
            // Send Slack/email notification or open a GitHub issue
            echo "Drift detected! Review plan.txt"
        }
    }
}
```

---

## Rollback Procedure

```bash
# List published Lambda versions
aws lambda list-versions-by-function --function-name pt-solution-api --region eu-central-1

# Roll back prod alias to a specific version
bash jenkins/scripts/deploy-lambda.sh rollback prod <version-number>

# Or: redeploy from a specific Git tag via Jenkins
# Trigger a build for the tagged commit in the Multibranch Pipeline
```
