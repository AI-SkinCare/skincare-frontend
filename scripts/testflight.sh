#!/bin/bash
# TestFlight 업로드: Release 아카이브 → App Store Connect 업로드 (Xcode에 로그인된 계정 사용).
# 빌드 번호는 매번 UTC 시각(YYYYMMDDHHMM)으로 올린다 — 같은 번호는 다시 올릴 수 없다.
# 사용: scripts/testflight.sh   (팀 ID는 Config/Local.xcconfig의 DEVELOPMENT_TEAM)
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
OUT="${OUT:-$(mktemp -d)}"
TEAM_ID="$(sed -nE 's/^DEVELOPMENT_TEAM *= *([A-Z0-9]+).*/\1/p' Config/Local.xcconfig 2>/dev/null | head -1)"
if [ -z "$TEAM_ID" ]; then
  echo "Config/Local.xcconfig에 DEVELOPMENT_TEAM이 필요해요" >&2
  exit 1
fi

echo "▶ 아카이브 (빌드 $BUILD_NUMBER) → $OUT"
xcodebuild -project SkinCare.xcodeproj -scheme SkinCare -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/SkinCare.xcarchive" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD_NUMBER" archive -quiet

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

echo "▶ 업로드"
xcodebuild -exportArchive -archivePath "$OUT/SkinCare.xcarchive" -exportPath "$OUT/upload" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates 2>&1 | grep -E "Upload succeeded|EXPORT|error" || true
echo "✓ 빌드 $BUILD_NUMBER 업로드 요청 완료. App Store Connect → TestFlight에서 처리(10–30분) 후 설치 가능"
