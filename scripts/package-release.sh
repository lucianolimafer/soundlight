#!/bin/bash

set -euo pipefail

readonly PRODUCT_NAME="SoundLight"
readonly VERSION="${1:?Usage: package-release.sh <version>}"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DIST_DIR="${PROJECT_ROOT}/dist"
readonly APP_BUNDLE="${DIST_DIR}/${PRODUCT_NAME}.app"
readonly CONTENTS_DIR="${APP_BUNDLE}/Contents"
readonly MACOS_DIR="${CONTENTS_DIR}/MacOS"
readonly ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}.app.zip"
readonly DMG_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}.dmg"
readonly VOLUME_DIR="${DIST_DIR}/dmg"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid semantic version: ${VERSION}" >&2
    exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${MACOS_DIR}" "${VOLUME_DIR}"

swift build -c release --arch arm64 --arch x86_64
readonly BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

install -m 755 "${BIN_PATH}/${PRODUCT_NAME}" "${MACOS_DIR}/${PRODUCT_NAME}"
install -m 644 "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "${CONTENTS_DIR}/Info.plist"
plutil -lint "${CONTENTS_DIR}/Info.plist"
lipo "${MACOS_DIR}/${PRODUCT_NAME}" -verify_arch arm64 x86_64

codesign --force --options runtime --sign "${CODE_SIGN_IDENTITY:--}" "${APP_BUNDLE}"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

cp -R "${APP_BUNDLE}" "${VOLUME_DIR}/"
ln -s /Applications "${VOLUME_DIR}/Applications"
hdiutil create \
    -volname "${PRODUCT_NAME}" \
    -srcfolder "${VOLUME_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "${DMG_PATH}"
shasum -a 256 "${ZIP_PATH}" "${DMG_PATH}" > "${DIST_DIR}/checksums.txt"
rm -rf "${VOLUME_DIR}" "${APP_BUNDLE}"

echo "Release artifacts created in ${DIST_DIR}"
