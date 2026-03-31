#!/usr/bin/env bash
# =============================================================================
# security-scan.sh — IaC security (Checkov) + secret detection (TruffleHog)
# Usage: security-scan.sh <checkov|trufflehog|all>
# =============================================================================
set -euo pipefail

MODE="${1:-all}"

run_checkov() {
  echo "==> Checkov — IaC Security Scan"
  pip install --quiet checkov

  checkov \
    --directory . \
    --output sarif \
    --output-file-path . \
    --soft-fail false \
    --skip-check CKV_GIT_1 \
    2>&1 | tee checkov-output.txt

  local exit_code=${PIPESTATUS[0]}

  if [[ $exit_code -ne 0 ]]; then
    echo "" >&2
    echo "Checkov found HIGH/CRITICAL findings. Review checkov.sarif and fix before merging." >&2
    echo "To temporarily skip a check, add it to --skip-check with a comment justifying why." >&2
    exit $exit_code
  fi

  echo "Checkov: PASSED (SARIF saved to checkov.sarif)"
}

run_trufflehog() {
  echo "==> TruffleHog — Secret Detection"

  # Prefer running via Docker to avoid version/dependency issues
  if command -v docker &>/dev/null; then
    docker run --rm \
      -v "$PWD:/repo:ro" \
      trufflesecurity/trufflehog:latest \
        git \
        file:///repo \
        --only-verified \
        --fail
  else
    # Fallback: install binary
    pip install --quiet trufflehog3
    trufflehog \
      git \
      "file://$PWD" \
      --only-verified \
      --fail
  fi

  echo "TruffleHog: PASSED"
}

case "$MODE" in
  checkov)    run_checkov ;;     
  trufflehog) run_trufflehog ;;  
  all)
    run_checkov
    run_trufflehog
    ;;
  *)
    echo "Unknown mode: $MODE. Use: checkov | trufflehog | all" >&2
    exit 1
    ;;
esac
