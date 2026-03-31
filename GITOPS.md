# GitOps Plan — `bahtiti/aws`

This document is the single source of truth for how changes flow through this repository, from a developer's branch to production.

---

## 1. Core Principles

| Principle | Implementation |
|-----------|---------------|
| **Git is the source of truth** | All infrastructure state is declared in this repo; no manual changes in AWS |
| **Declarative** | Resources described as desired state (IaC), not imperative scripts |
| **Automated** | Every merge triggers automated linting, security scanning, and deployment |
| **Auditable** | Every change has a PR, a review, and a commit history |
| **Reversible** | Every change to `main` creates a tagged release; rollback = deploy previous tag |

---

## 2. Branch Strategy — Strict Promotion Hierarchy

```
feature/*  fix/*  chore/*  docs/*  refactor/*  perf/*  ci/*  test/*  build/*
       │
       ▼  (PR + 1 approval)
    develop  ─────────────►  DEV environment
       │
       ▼  (PR + 2 approvals)
    staging  ─────────────►  STAGING environment
       │
       ▼  (PR + 2 approvals + CODEOWNERS)
      main   ─────────────►  PRODUCTION environment

hotfix/*  ────────────────►  main (+ back-merge to staging & develop)
```

### Branch rules

| Branch | Purpose | Allowed sources | Required approvals | Deployable |
|--------|---------|----------------|-------------------|------------|
| `main` | Production | `staging`, `hotfix/*` | **2** (CODEOWNERS mandatory) | Yes — prod |
| `staging` | Pre-production QA | `develop`, `hotfix/*` | **2** | Yes — staging |
| `develop` | Integration & dev | `feature/*`, `fix/*`, `chore/*`, `docs/*`, `refactor/*`, `perf/*`, `ci/*`, `test/*`, `build/*` | **1** | Yes — dev |
| `feature/*` | New features | _personal_ | — | No |
| `fix/*` | Non-critical fixes | _personal_ | — | No |
| `hotfix/*` | Critical prod fixes | `main` | **2** (fast-track) | After merge |
| `release/*` | Optional release prep | `develop` | **2** | No |

### Branch naming convention

```
feature/ISSUE-123-short-description
fix/ISSUE-456-short-description
hotfix/ISSUE-789-short-description
chore/update-dependencies
docs/improve-readme
ci/add-checkov-scan
```

---

## 3. Pull Request Lifecycle

```
1. Developer opens PR from feature branch → develop
   └─ PR template auto-loaded
   └─ Auto-labels applied (actions/labeler)
   └─ Assignees set

2. CI Quality Gates run automatically
   └─ PR title check (Conventional Commits)
   └─ PR description check
   └─ Branch promotion policy check
   └─ YAML/JSON lint
   └─ CloudFormation lint (cfn-lint)
   └─ Terraform fmt + TFLint
   └─ IaC security scan (Checkov → SARIF → GitHub Security tab)
   └─ Secret scan (TruffleHog)
   └─ Markdown lint

3. Code Review
   └─ At least 1 approval required (develop), 2 for staging/main
   └─ CODEOWNERS review required for main
   └─ Stale reviews dismissed on new commits

4. Merge (squash preferred for features, merge for promotions)
   └─ Branch deleted automatically after merge

5. Post-merge
   └─ semantic-release creates tag + GitHub Release + CHANGELOG entry
   └─ Deployment pipeline triggered (when configured)
```

---

## 4. Quality Gates Summary

| Gate | Tool | Blocks merge? | Scope |
|------|------|--------------|-------|
| PR title format | `action-semantic-pull-request` | Yes | All PRs |
| PR description | GitHub Script | Yes | All PRs |
| Branch promotion policy | GitHub Script | Yes | All PRs |
| YAML lint | `yamllint` | Yes | All PRs |
| CloudFormation lint | `cfn-lint` | Yes | PRs with CFN templates |
| Terraform format | `terraform fmt -check` | Yes | PRs with `.tf` files |
| Terraform lint | `tflint` | Yes | PRs with `.tf` files |
| IaC security scan | `checkov` | Yes | All PRs |
| Secret detection | `trufflehog` | Yes | All PRs |
| Markdown lint | `markdownlint-cli2` | Yes | All PRs |
| CODEOWNERS review | GitHub native | Yes | PRs to `main` |
| Drift detection | Terraform Plan | Opens issue | Nightly |

---

## 5. Versioning — Semantic Versioning (SemVer)

Versions follow **MAJOR.MINOR.PATCH** (e.g. `v1.4.2`).

### How versions are bumped

Version bumps are driven by **Conventional Commits** in the PR title:

| Commit type | Version bump | Example |
|-------------|-------------|--------|
| `feat:` | MINOR ↑ | `feat(lambda): add SQS trigger` |
| `fix:` / `hotfix:` / `perf:` / `refactor:` | PATCH ↑ | `fix(iam): correct policy ARN` |
| `feat!:` or `BREAKING CHANGE:` footer | MAJOR ↑ | `feat!: remove legacy VPC` |
| `docs:` / `chore:` / `ci:` | No release | — |

### Pre-release versions

| Branch | Tag format | Example |
|--------|------------|--------|
| `main` | `v1.2.3` | Production release |
| `staging` | `v1.2.3-rc.1` | Release candidate |
| `develop` | `v1.2.3-dev.1` | Development pre-release |

### Tagging

Tags are **automatically created** by `semantic-release` on every merge to `main`, `staging`, or `develop`. Never create tags manually.

---

## 6. Branch Protection Rules (GitHub Settings)

Apply these rules in **Settings → Branches** for each protected branch.

### `main`

```
✔ Require a pull request before merging
  ✔ Required approvals: 2
  ✔ Dismiss stale pull request approvals when new commits are pushed
  ✔ Require review from Code Owners
  ✔ Require approval of the most recent reviewable push

✔ Require status checks to pass before merging
  ✔ Require branches to be up to date before merging
  Required checks:
    • Conventional Commit Title
    • PR Description Required
    • Branch Promotion Policy
    • YAML & JSON Lint
    • CloudFormation Lint
    • Terraform Lint & Validate
    • IaC Security Scan (Checkov)
    • Secret Scan (TruffleHog)
    • Markdown Lint

✔ Require signed commits
✔ Require linear history
✔ Include administrators
✔ Restrict who can push to matching branches → [team lead / release bot only]
✔ Allow force pushes: DISABLED
✔ Allow deletions: DISABLED
```

### `staging`

```
✔ Require a pull request before merging
  ✔ Required approvals: 2
  ✔ Dismiss stale pull request approvals when new commits are pushed

✔ Require status checks to pass (same list as main)
✔ Require linear history
✔ Include administrators
✔ Allow force pushes: DISABLED
✔ Allow deletions: DISABLED
```

### `develop`

```
✔ Require a pull request before merging
  ✔ Required approvals: 1
  ✔ Dismiss stale pull request approvals when new commits are pushed

✔ Require status checks to pass (same list as main)
✔ Allow force pushes: DISABLED
✔ Allow deletions: DISABLED
```

---

## 7. Hotfix Process

For critical production incidents that cannot wait for the normal promotion flow:

```bash
# 1. Branch from main (NOT develop)
git checkout main
git pull origin main
git checkout -b hotfix/ISSUE-999-fix-lambda-timeout

# 2. Make the fix, commit with Conventional Commits
git commit -m "hotfix(lambda): increase timeout to prevent cold-start failures"

# 3. Open PR directly to main (CI + 2 approvals required)
# 4. After merge to main, semantic-release creates a patch tag (e.g. v1.2.4)

# 5. Back-merge to staging and develop to keep branches in sync
git checkout staging && git merge main && git push origin staging
git checkout develop && git merge main && git push origin develop
```

---

## 8. Rollback Strategy

```bash
# List recent releases
gh release list

# Roll back to a specific version tag
# Option A: Revert via PR (preferred — maintains audit trail)
git checkout main
git revert HEAD~1  # or revert specific commits
git push origin main  # triggers normal PR flow

# Option B: Emergency — redeploy previous tag directly
gh workflow run release.yml -f tag=v1.2.2
```

---

## 9. Merge Strategy

| Target | Merge strategy | Reason |
|--------|---------------|--------|
| `develop` ← `feature/*` | **Squash merge** | Clean linear history |
| `staging` ← `develop` | **Merge commit** | Preserve promotion audit trail |
| `main` ← `staging` | **Merge commit** | Full traceable promotion |
| `main` ← `hotfix/*` | **Squash merge** | Single clean hotfix commit |

---

## 10. AWS Credentials — OIDC (No Long-Lived Keys)

All GitHub Actions authenticate to AWS using **OIDC** — no AWS access keys stored in repository secrets.

Required GitHub secret / variable:

| Name | Type | Description |
|------|------|-------------|
| `AWS_ROLE_ARN` | Secret | IAM Role ARN for OIDC authentication |
| `AWS_REGION` | Variable | Default AWS region (e.g. `eu-central-1`) |

IAM trust policy must allow `token.actions.githubusercontent.com` as the identity provider.
