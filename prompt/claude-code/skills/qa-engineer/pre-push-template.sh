#!/bin/sh
# Pre-push hook template for Next.js + Supabase projects
#
# Install:
#   cp pre-push-template.sh .git/hooks/pre-push && chmod +x .git/hooks/pre-push
#
# Or create a scripts/install-hooks.sh in your project that writes this to .git/hooks/
#
# What it does:
#   1. npm run preflight (lint + unit test + build + smoke E2E)
#   2. Blocks push if any step fails
#
# Customize:
#   - Change 'npm run preflight' to match your project's validation script
#   - Add additional checks (e.g., type-check, security audit)

echo "Running preflight checks..."
npm run preflight
if [ $? -ne 0 ]; then
  echo ""
  echo "========================================="
  echo "  Preflight FAILED. Push aborted."
  echo "========================================="
  echo ""
  echo "Fix the issues above, then try again."
  echo "To skip (NOT recommended): git push --no-verify"
  exit 1
fi

echo ""
echo "Preflight passed. Pushing..."

# Entire CLI hooks (if available)
command -v entire >/dev/null 2>&1 && entire hooks git pre-push "$1" || true
