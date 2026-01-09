#!/bin/zsh
# Usage: ./scripts/upload_to_testflight.sh YOUR_APPLE_ID APP_SPECIFIC_PASSWORD
# Pre-requisites: You are logged into Xcode with your developer account and have the correct Team selected.

set -euo pipefail
WORKDIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$WORKDIR/build"
ARCHIVE_PATH="$BUILD_DIR/Yogik.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
IPA_PATH="$EXPORT_PATH/Yogik.ipa"

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 APPLE_ID APP_SPECIFIC_PASSWORD"
  exit 1
fi
APPLE_ID=$1
APP_SPECIFIC_PASSWORD=$2

mkdir -p "$BUILD_DIR"
mkdir -p "$EXPORT_PATH"

echo "Archiving the app..."
xcodebuild -project "$WORKDIR/Yogik.xcodeproj" -scheme Yogik -configuration Release -sdk iphoneos -archivePath "$ARCHIVE_PATH" archive

echo "Exporting .ipa using ExportOptions.plist..."
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportOptionsPlist "$WORKDIR/ExportOptions.plist" -exportPath "$EXPORT_PATH"

if [ ! -f "$IPA_PATH" ]; then
  # some xcodebuild setups name the ipa differently; try to find one
  IPA_PATH_FOUND=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1 || true)
  if [ -z "$IPA_PATH_FOUND" ]; then
    echo "No .ipa found in $EXPORT_PATH"
    exit 1
  fi
  IPA_PATH="$IPA_PATH_FOUND"
fi

echo "Uploading .ipa to App Store Connect using altool (requires app-specific password)..."
xcrun altool --upload-app -f "$IPA_PATH" -u "$APPLE_ID" -p "$APP_SPECIFIC_PASSWORD" --type ios --verbose

echo "Upload complete. Check App Store Connect -> My Apps -> Your App -> TestFlight for processing status."
