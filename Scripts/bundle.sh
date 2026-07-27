#!/usr/bin/env bash
#
# bundle.sh — builds the SwiftPM executable in release mode and assembles a
# double-clickable "dist/DualSense Remap.app" bundle, ad-hoc signed.
#
# A real .app bundle (instead of a bare binary) is required so macOS TCC
# attributes the Accessibility / Input Monitoring grants to the app itself
# and not to the invoking terminal (see docs/PERMISSIONS.md).
#
# Usage: Scripts/bundle.sh          (or: make app)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DualSense Remap"
EXECUTABLE_NAME="DualSenseRemap"
DIST_DIR="${REPO_ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

echo "==> Compilation (swift build -c release)…"
swift build -c release --package-path "${REPO_ROOT}"

RELEASE_BINARY="${REPO_ROOT}/.build/release/${EXECUTABLE_NAME}"
if [[ ! -x "${RELEASE_BINARY}" ]]; then
    echo "error: release binary not found at ${RELEASE_BINARY}" >&2
    exit 1
fi

echo "==> Assemblage de ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BINARY}" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"
cp "${REPO_ROOT}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# Ship the Hammerspoon Spoon inside the bundle: HammerspoonBridge.installSpoon()
# looks for "DualSenseRemap.spoon" in Contents/Resources first.
SPOON_SOURCE="${REPO_ROOT}/Hammerspoon/DualSenseRemap.spoon"
if [[ -d "${SPOON_SOURCE}" ]]; then
    ditto "${SPOON_SOURCE}" "${APP_BUNDLE}/Contents/Resources/DualSenseRemap.spoon"
fi

echo "==> Signature ad hoc (codesign --sign -)…"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "✔ Terminé : ${APP_BUNDLE}"
echo ""
echo "  Ouvrir l'application :"
echo "    open \"${APP_BUNDLE}\""
echo ""
echo "  Première ouverture (signature ad hoc) : dans le Finder, clic droit"
echo "  sur « ${APP_NAME}.app » → « Ouvrir » → « Ouvrir » pour passer"
echo "  l'avertissement Gatekeeper."
echo ""
echo "  Installation dans /Applications :"
echo "    make install"
