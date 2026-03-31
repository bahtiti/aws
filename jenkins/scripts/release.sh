#!/usr/bin/env bash
# =============================================================================
# release.sh — Semantic versioning, tagging, and CHANGELOG via semantic-release
#
# Driven by Conventional Commits on main/staging/develop:
#   feat:            → MINOR bump  (v1.1.0)
#   fix / hotfix:    → PATCH bump  (v1.0.1)
#   feat! / BREAKING → MAJOR bump  (v2.0.0)
#   docs / chore:    → no release
#
# Pre-release channels:
#   main    → v1.2.3        (production)
#   staging → v1.2.3-rc.1   (release candidate)
#   develop → v1.2.3-dev.1  (development)
#
# Required env vars:
#   GITHUB_TOKEN  – personal access token with repo scope
# =============================================================================
set -euo pipefail

echo "==> Semantic Release"

# Node.js is required on the Jenkins agent
node --version
npm --version

# Install semantic-release and required plugins (local, no global install needed)
echo "Installing semantic-release plugins..."
npm install --no-save \
  semantic-release@latest \
  "@semantic-release/changelog" \
  "@semantic-release/git" \
  "@semantic-release/github" \
  "@semantic-release/commit-analyzer" \
  "@semantic-release/release-notes-generator" \
  conventional-changelog-conventionalcommits

# Configure git identity for the automated release commit
git config user.email "jenkins-release-bot@ci.local"
git config user.name "Jenkins Release Bot"

# Run semantic-release (reads config from .releaserc.json)
echo "Running semantic-release..."
npx semantic-release

echo "==> Release complete"
