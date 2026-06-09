#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: ./release.sh <version>  (e.g. ./release.sh v0.1.0-alpha)" >&2
  exit 1
fi

# Validate format: vX.Y.Z or vX.Y.Z-suffix
if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
  echo "Error: version must match vX.Y.Z or vX.Y.Z-suffix (e.g. v1.0.0-alpha)" >&2
  exit 1
fi

BARE="${VERSION#v}"   # strip leading 'v' for pubspec.yaml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Abort if this tag already exists locally or on the remote
if git tag | grep -qx "${VERSION}"; then
  echo "Error: tag ${VERSION} already exists locally — did you mean a new version?" >&2
  exit 1
fi
if git ls-remote --tags origin | grep -q "refs/tags/${VERSION}$"; then
  echo "Error: tag ${VERSION} already exists on remote." >&2
  exit 1
fi

# Abort if there are uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree has uncommitted changes — commit or stash first." >&2
  exit 1
fi

echo "Bumping pubspec.yaml → ${BARE}..."
sed -i '' "s/^version: .*/version: ${BARE}+1/" pubspec.yaml

# Only commit if pubspec.yaml actually changed (re-releasing same version is a no-op)
if git diff --quiet pubspec.yaml; then
  echo "Error: pubspec.yaml already has version ${BARE}+1 — nothing to commit." >&2
  echo "       Did you mean a new version number?" >&2
  exit 1
fi

echo "Committing version bump..."
git add pubspec.yaml
git commit -m "chore: bump version to ${VERSION}"

echo "Creating tag ${VERSION}..."
git tag "${VERSION}"

echo "Pushing commit and tag..."
git push
git push origin "${VERSION}"

# Derive repo slug from remote URL
# Handles both https://github.com/user/repo.git and git@github.com:user/repo.git
REMOTE="$(git remote get-url origin)"
REPO="$(echo "${REMOTE%.git}" | sed -E 's|^.*[:/]([^/]+/[^/]+)$|\1|')"

echo ""
echo "Done. Tag ${VERSION} pushed — GitHub Actions is building now."
echo "  Watch:   https://github.com/${REPO}/actions"
echo "  Release: https://github.com/${REPO}/releases/tag/${VERSION}"
