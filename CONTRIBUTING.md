# Contributing Guide

Thank you for contributing to this repository. Please read this guide before opening a PR.

---

## Quick Reference

| What | Where |
|------|-------|
| Branch strategy | [GITOPS.md#2](GITOPS.md#2-branch-strategy--strict-promotion-hierarchy) |
| PR lifecycle | [GITOPS.md#3](GITOPS.md#3-pull-request-lifecycle) |
| Quality gates | [GITOPS.md#4](GITOPS.md#4-quality-gates-summary) |
| Versioning | [GITOPS.md#5](GITOPS.md#5-versioning--semantic-versioning-semver) |
| Hotfix process | [GITOPS.md#7](GITOPS.md#7-hotfix-process) |

---

## 1. Before You Start

1. Check [open issues](../../issues) — your change may already be tracked.
2. For large changes, open an issue first to discuss the approach.
3. Clone the repo and create a branch from `develop` (not `main`).

---

## 2. Branch Naming

```
feature/ISSUE-123-short-description    # new feature
fix/ISSUE-456-short-description        # bug fix
chore/update-terraform-providers       # maintenance
docs/improve-iam-guide                 # documentation
ci/add-tflint-step                     # CI changes
refactor/simplify-vpc-module           # refactoring
hotfix/ISSUE-789-critical-fix          # critical prod fix (branch from main)
```

---

## 3. Commit Message Format (Conventional Commits)

All commit messages **and PR titles** must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short description>

[optional body]

[optional footer: BREAKING CHANGE: ...]
```

### Allowed types

| Type | When to use | Version bump |
|------|------------|-------------|
| `feat` | New feature or resource | MINOR |
| `fix` | Bug fix | PATCH |
| `hotfix` | Critical production fix | PATCH |
| `perf` | Performance improvement | PATCH |
| `refactor` | Code change that is not a fix or feature | PATCH |
| `docs` | Documentation only | None |
| `chore` | Build, deps, or tooling | None |
| `ci` | CI/CD pipeline changes | None |
| `test` | Adding or fixing tests | None |
| `build` | Build system changes | None |

### Breaking changes

Append `!` to the type or add a `BREAKING CHANGE:` footer:

```
feat!(vpc): replace legacy VPC with Transit Gateway

BREAKING CHANGE: existing VPC peering connections must be recreated.
```

### Examples

```
feat(lambda): add SQS trigger for order processing
fix(iam): correct missing s3:GetObject permission
chore(deps): update AWS provider to 5.40
docs: add Lambda invocation examples to README
ci: add TruffleHog secret scanning step
```

---

## 4. Opening a Pull Request

1. Push your branch and open a PR against `develop`.
2. Fill in **every section** of the PR template — empty descriptions are auto-rejected.
3. Ensure your PR title follows Conventional Commits (CI will check this).
4. Wait for all CI checks to pass before requesting review.
5. Request review from the CODEOWNERS (auto-requested for `main` PRs).

---

## 5. Code Review Expectations

- Reviewers should respond within **1 business day**.
- All comments must be resolved before merging.
- Reviewers check: correctness, security, least-privilege IAM, idempotency.
- Authors must not merge their own PRs (even if they have the permission).

---

## 6. IaC Standards

### AWS / CloudFormation
- Use `Parameters` for environment-specific values.
- Tag all resources with at minimum: `Environment`, `Project`, `Owner`, `ManagedBy=GitOps`.
- Never use `*` in IAM `Action` or `Resource` without documented justification.

### Terraform (if applicable)
- Run `terraform fmt` before committing.
- Pin provider versions.
- Use workspaces or separate state per environment.
- Store state in S3 with DynamoDB locking.

---

## 7. Security Rules (Non-Negotiable)

- **No hardcoded secrets** — use AWS Secrets Manager or Parameter Store.
- **No public S3 buckets** unless explicitly required and approved.
- **No open security groups** (0.0.0.0/0 ingress) without documented justification.
- **No wildcard IAM policies** in production.
- All CI security checks must pass — `checkov` and `trufflehog` failures block merge.

---

## 8. Versioning

Do **not** manually create tags or update `CHANGELOG.md`. These are automated:
- Merging to `main` → `semantic-release` creates a SemVer tag and GitHub Release.
- Merging to `staging` → creates an `rc` pre-release tag.
- Merging to `develop` → creates a `dev` pre-release tag.
