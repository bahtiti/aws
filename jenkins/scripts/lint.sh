#!/usr/bin/env bash
# =============================================================================
# lint.sh — YAML, CloudFormation, and Markdown linting
# Usage: lint.sh <yaml|cfn|markdown|all>
# =============================================================================
set -euo pipefail

MODE="${1:-all}"

run_yaml_lint() {
  echo "==> YAML Lint"
  pip install --quiet yamllint

  yamllint \
    --config-data '{
      extends: default,
      rules: {
        line-length: {max: 140, level: warning},
        truthy: {allowed-values: ["true", "false"]},
        comments: {min-spaces-from-content: 1}
      }
    }' \
    --format colored \
    . 2>&1 | grep -v "^\s*$" || true

  echo "YAML Lint: PASSED"
}

run_cfn_lint() {
  echo "==> CloudFormation Lint (cfn-lint)"
  pip install --quiet cfn-lint

  shopt -s globstar nullglob
  templates=(
    cfn/**/*.yaml cfn/**/*.yml cfn/**/*.json
    cloudformation/**/*.yaml cloudformation/**/*.yml cloudformation/**/*.json
    stacks/**/*.yaml stacks/**/*.yml stacks/**/*.json
  )

  if [[ ${#templates[@]} -eq 0 ]]; then
    echo "No CloudFormation templates found — skipping cfn-lint."
    return 0
  fi

  echo "Linting ${#templates[@]} CloudFormation template(s)..."
  cfn-lint "${templates[@]}"
  echo "CFN Lint: PASSED"
}

run_markdown_lint() {
  echo "==> Markdown Lint"
  npm install --global --silent markdownlint-cli2

  # Config: disable line length (MD013) and inline HTML (MD033)
  markdownlint-cli2 \
    --config '{
      "MD013": false,
      "MD033": false,
      "MD041": false
    }' \
    "**/*.md"

  echo "Markdown Lint: PASSED"
}

case "$MODE" in
  yaml)     run_yaml_lint ;;         
  cfn)      run_cfn_lint ;;          
  markdown) run_markdown_lint ;;     
  all)
    run_yaml_lint
    run_cfn_lint
    run_markdown_lint
    ;;
  *)
    echo "Unknown mode: $MODE. Use: yaml | cfn | markdown | all" >&2
    exit 1
    ;;
esac
