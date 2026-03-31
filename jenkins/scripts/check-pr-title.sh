#!/usr/bin/env bash
# =============================================================================
# check-pr-title.sh — Enforce Conventional Commits format on PR titles
# Usage: check-pr-title.sh "<pr title>"
# =============================================================================
set -euo pipefail

PR_TITLE="${1:-}"

if [[ -z "$PR_TITLE" ]]; then
  echo "ERROR: PR title argument is empty." >&2
  exit 1
fi

# Conventional Commits pattern:
#   <type>(<optional scope>)<!>: <description (min 3 chars)>
#   type: one of the allowed list
#   scope: optional, alphanumeric + hyphens/underscores/slashes
#   !: optional, marks a breaking change
PATTERN='^(feat|fix|hotfix|docs|chore|refactor|perf|ci|test|build)(\([a-zA-Z0-9/_-]+\))?(!)?: .{3,}$'

if echo "$PR_TITLE" | grep -qE "$PATTERN"; then
  echo "PR title check PASSED: $PR_TITLE"
  exit 0
fi

echo "" >&2
echo "ERROR: PR title does not follow Conventional Commits format." >&2
echo "" >&2
echo "  Got     : $PR_TITLE" >&2
echo "" >&2
echo "  Required: <type>(<scope>): <description>" >&2
echo "" >&2
echo "  Allowed types:" >&2
echo "    feat      – new feature                   (version bump: MINOR)" >&2
echo "    fix       – bug fix                        (version bump: PATCH)" >&2
echo "    hotfix    – critical production fix         (version bump: PATCH)" >&2
echo "    perf      – performance improvement         (version bump: PATCH)" >&2
echo "    refactor  – refactor without fix/feature    (version bump: PATCH)" >&2
echo "    docs      – documentation only              (no release)" >&2
echo "    chore     – build / deps / maintenance      (no release)" >&2
echo "    ci        – CI/CD pipeline changes          (no release)" >&2
echo "    test      – adding or fixing tests          (no release)" >&2
echo "    build     – build system changes            (no release)" >&2
echo "" >&2
echo "  Breaking change: append ! to the type (feat!: ...) or add" >&2
echo "  BREAKING CHANGE: footer in the commit body." >&2
echo "" >&2
echo "  Examples:" >&2
echo "    feat(lambda): add SQS trigger for order processing" >&2
echo "    fix(iam): correct missing s3:GetObject permission" >&2
echo "    chore(deps): update AWS provider to 5.40" >&2
echo "    feat!: migrate to new VPC CIDR (breaking change)" >&2
echo "" >&2
exit 1
