#!/bin/bash
#
# setup-hooks.sh — configures git to use project hooks from .githooks/
# Run once after cloning: ./scripts/setup-hooks.sh
#

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)

git config core.hooksPath .githooks
chmod +x "$REPO_ROOT/.githooks/"*

echo "Git hooks configured:"
ls -la "$REPO_ROOT/.githooks/"
echo ""
echo "Active hooks path: $(git config core.hooksPath)"
echo ""
echo "Available scripts:"
ls -la "$REPO_ROOT/scripts/"
