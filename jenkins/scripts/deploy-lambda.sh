#!/usr/bin/env bash
# =============================================================================
# deploy-lambda.sh — Build, package, and deploy AWS Lambda
# Usage:
#   deploy-lambda.sh build                  – package artifact only
#   deploy-lambda.sh deploy <env>            – build + deploy + smoke test
#   deploy-lambda.sh smoke-test <env>        – smoke test only
#
# Environment variables (set by Jenkins or caller):
#   LAMBDA_FUNCTION  – Lambda function name (required)
#   AWS_REGION       – AWS region (default: eu-central-1)
#   BUILD_NUMBER     – Jenkins build number (optional, for description)
#   GIT_BRANCH       – Source branch (optional, for description)
#   GIT_COMMIT       – Commit SHA (optional, for description)
# =============================================================================
set -euo pipefail

ACTION="${1:-build}"
ENVIRONMENT="${2:-dev}"

# ── Config ─────────────────────────────────────────────────────────────────────────────
FUNCTION_NAME="${LAMBDA_FUNCTION:?'LAMBDA_FUNCTION env var is required'}"
REGION="${AWS_REGION:-eu-central-1}"
ARTIFACT="lambda-artifact.zip"
DESCRIPTION="Build #${BUILD_NUMBER:-local} | Branch: ${GIT_BRANCH:-unknown} | SHA: ${GIT_COMMIT:-unknown}"

# Lambda alias = environment name
declare -A ALIAS_MAP=([dev]="dev" [staging]="staging" [prod]="prod")
ALIAS="${ALIAS_MAP[$ENVIRONMENT]:-dev}"

# ── Helpers ──────────────────────────────────────────────────────────────────────────
log()  { echo "[deploy-lambda] $*"; }
error(){ echo "[deploy-lambda] ERROR: $*" >&2; exit 1; }

# ── Build: package function code into a ZIP ─────────────────────────────────────
build() {
  log "Building Lambda artifact: ${ARTIFACT}"
  rm -f "${ARTIFACT}"

  # ▶ Adapt this block to your runtime:
  # ───────────────────────────────────────────────────────────────────────
  # Node.js:
  #   npm ci --omit=dev
  #   zip -r "${ARTIFACT}" . -x ".git/*" -x "tests/*" -x "*.md" -x "jenkins/*"
  #
  # Python:
  #   pip install -r requirements.txt --target ./vendor
  #   cd vendor && zip -r "../${ARTIFACT}" . && cd ..
  #   zip -g "${ARTIFACT}" src/*.py
  #
  # PHP (Lambda Layer):
  #   composer install --no-dev --optimize-autoloader
  #   zip -r "${ARTIFACT}" . -x ".git/*" -x "tests/*" -x "jenkins/*" -x "*.md"
  # ───────────────────────────────────────────────────────────────────────

  # Generic fallback (zip repo contents, exclude dev files)
  zip -r "${ARTIFACT}" . \
    --exclude ".git/*" \
    --exclude "tests/*" \
    --exclude "*.md" \
    --exclude "jenkins/*" \
    --exclude ".github/*" \
    --exclude "node_modules/.cache/*"

  log "Artifact ready: ${ARTIFACT} ($(du -sh ${ARTIFACT} | cut -f1))"
}

# ── Deploy: upload + publish version + update alias ───────────────────────────
deploy() {
  log "Deploying to environment: ${ENVIRONMENT} (alias: ${ALIAS})"
  log "Function: ${FUNCTION_NAME} | Region: ${REGION}"

  # 1. Upload new code
  log "Step 1/4: Uploading artifact..."
  aws lambda update-function-code \
    --function-name "${FUNCTION_NAME}" \
    --zip-file "fileb://${ARTIFACT}" \
    --region "${REGION}" \
    --output text

  # 2. Wait for code update to finish
  log "Step 2/4: Waiting for update-function-code to complete..."
  aws lambda wait function-updated \
    --function-name "${FUNCTION_NAME}" \
    --region "${REGION}"

  # 3. Publish a new immutable version
  log "Step 3/4: Publishing new version..."
  VERSION=$(aws lambda publish-version \
    --function-name "${FUNCTION_NAME}" \
    --description "${DESCRIPTION}" \
    --region "${REGION}" \
    --query 'Version' \
    --output text)
  log "Published version: ${VERSION}"

  # 4. Point alias to the new version
  log "Step 4/4: Updating alias '${ALIAS}' → version ${VERSION}..."
  aws lambda update-alias \
    --function-name "${FUNCTION_NAME}" \
    --name "${ALIAS}" \
    --function-version "${VERSION}" \
    --region "${REGION}" \
    --output text 2>/dev/null \
  || aws lambda create-alias \
    --function-name "${FUNCTION_NAME}" \
    --name "${ALIAS}" \
    --function-version "${VERSION}" \
    --region "${REGION}" \
    --output text

  log "Deploy complete: ${FUNCTION_NAME}:${ALIAS} → v${VERSION}"
}

# ── Smoke test: invoke the function and verify HTTP 200 ───────────────────────
smoke_test() {
  log "Running smoke test on ${FUNCTION_NAME}:${ALIAS}..."

  local response_file
  response_file=$(mktemp)

  STATUS=$(aws lambda invoke \
    --function-name "${FUNCTION_NAME}:${ALIAS}" \
    --cli-binary-format raw-in-base64-out \
    --payload '{"action":"health-check"}' \
    --region "${REGION}" \
    --query 'StatusCode' \
    --output text \
    "${response_file}" 2>&1)

  log "Response body:"
  cat "${response_file}"
  rm -f "${response_file}"

  if [[ "${STATUS}" != "200" ]]; then
    error "Smoke test FAILED: HTTP status ${STATUS} (expected 200)."
  fi

  log "Smoke test: PASSED (HTTP ${STATUS})"
}

# ── Rollback: point alias back to a previous version ────────────────────────
rollback() {
  local TARGET_VERSION="${3:?'rollback requires a version number as 3rd argument'}"
  log "Rolling back ${FUNCTION_NAME}:${ALIAS} → v${TARGET_VERSION}"

  aws lambda update-alias \
    --function-name "${FUNCTION_NAME}" \
    --name "${ALIAS}" \
    --function-version "${TARGET_VERSION}" \
    --region "${REGION}" \
    --output text

  log "Rollback complete: ${FUNCTION_NAME}:${ALIAS} → v${TARGET_VERSION}"
}

# ── Dispatch ────────────────────────────────────────────────────────────────────────────
case "${ACTION}" in
  build)       build ;;                       
  deploy)      build && deploy && smoke_test ;;
  smoke-test)  smoke_test ;;                  
  rollback)    rollback "$@" ;;               
  *)
    echo "Usage: $0 <build|deploy <env>|smoke-test <env>|rollback <env> <version>>" >&2
    exit 1
    ;;
esac
