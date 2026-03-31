## Description

> Clearly explain **what** this PR does and **why**. Link the related issue below.

Closes #<!-- issue number -->

---

## Type of Change

<!-- Check all that apply -->
- [ ] `feat` – New feature
- [ ] `fix` – Bug fix
- [ ] `docs` – Documentation only
- [ ] `refactor` – Code refactor (no feature/fix)
- [ ] `chore` – Build, CI, or dependency update
- [ ] `hotfix` – Critical production fix
- [ ] `BREAKING CHANGE` – Breaking change (explain below)

---

## Quality Gates Checklist

### Code Quality
- [ ] My code follows the project conventions in `CONTRIBUTING.md`
- [ ] PR title follows Conventional Commits format (`type(scope): description`)
- [ ] All new IaC files are linted (`terraform fmt`, `cfn-lint`, `yaml-lint`)
- [ ] No hardcoded secrets, credentials, or sensitive data

### Security
- [ ] Security scan (Checkov) passes with no new HIGH/CRITICAL findings
- [ ] Secret scan (TruffleHog) passes with no new findings
- [ ] IAM permissions follow least-privilege principle
- [ ] No public S3 buckets, open security groups, or wildcard permissions introduced

### Infrastructure
- [ ] Infrastructure changes are idempotent and reversible
- [ ] Changes have been tested in `develop` environment before targeting `staging`
- [ ] Changes have been tested in `staging` before targeting `main`
- [ ] Rollback plan documented (if applicable)

### Testing & Validation
- [ ] All CI checks pass
- [ ] Changes validated in the target AWS account/environment
- [ ] Drift detection reviewed (no unintended state changes)

### Documentation
- [ ] Relevant documentation updated
- [ ] `CHANGELOG.md` entry added (if not using semantic-release)

---

## Environment Promotion

| Environment | Status |
|------------|--------|
| `develop` | <!-- Tested / N/A --> |
| `staging` | <!-- Tested / N/A --> |
| `main` (prod) | <!-- Pending approval --> |

---

## Breaking Changes

> If this PR introduces breaking changes, describe the impact and migration steps.

_None_ <!-- or describe -->

---

## Additional Context / Screenshots

<!-- Any additional context, AWS console screenshots, or logs -->
