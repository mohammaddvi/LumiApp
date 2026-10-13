#!/usr/bin/env bash
# Capture App Store screenshots + a short preview video from the iOS Simulator.
# Usage:
#   scripts/capture-app-store-screenshots.sh           # iPhone 6.9" + 6.5" + preview
#   scripts/capture-app-store-screenshots.sh iphone    # same as default
#   scripts/capture-app-store-screenshots.sh ipad      # 13-inch iPad only
#   scripts/capture-app-store-screenshots.sh all       # iPhone + iPad
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-iphone}"

# iPhone 16 Pro Max — 6.9" class (1320×2868)
IPHONE_DEVICE_ID="${SIMULATOR_UDID:-A44AC6CE-F89D-4436-B9EE-16400955F660}"
# iPad Pro 13-inch (M5) — App Store 13" slot (2064×2752)
IPAD_DEVICE_ID="${IPAD_SIMULATOR_UDID:-5637A2CF-F5E8-49DB-8443-EB794DDB08EA}"
IPAD_TARGET_W=2064
IPAD_TARGET_H=2752

BUNDLE_ID="app.lune.tracker"
DERIVED="${ROOT}/build/DerivedData"
APP="${DERIVED}/Build/Products/Debug-iphonesimulator/Lumi.app"
OUT_ROOT="${ROOT}/AppStoreMarketing"
OUT_69="${OUT_ROOT}/screenshots/6.9-iphone"
OUT_65="${OUT_ROOT}/screenshots/6.5-iphone"
OUT_IPAD="${OUT_ROOT}/screenshots/13-inch-ipad"
OUT_PREVIEW="${OUT_ROOT}/preview"
SCREENS=(splash today ask insights settings)

capture_screen() {
  local device_id="$1"
  local screen="$2"
  local dest="$3"
  echo "  • ${screen}"
  xcrun simctl terminate "${device_id}" "${BUNDLE_ID}" 2>/dev/null || true
  xcrun simctl launch "${device_id}" "${BUNDLE_ID}" \
    -AppStoreScreenshots \
    -ScreenshotScreen "${screen}" >/dev/null
  # Splash holds; other screens wait for seed + short splash dismiss.
  if [[ "${screen}" == "splash" ]]; then
    sleep 2.5
  else
    sleep 5.0
  fi
  xcrun simctl io "${device_id}" screenshot --type=png "${dest}"
}

ensure_build_and_install() {
  local device_id="$1"
  echo "→ Booting simulator ${device_id}…"
  xcrun simctl boot "${device_id}" 2>/dev/null || true
  xcrun simctl bootstatus "${device_id}" -b

  echo "→ Building Lumi (Debug)…"
  xcodebuild \
    -scheme Cycle \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${device_id}" \
    -derivedDataPath "${DERIVED}" \
    build | tail -20

  echo "→ Installing…"
  xcrun simctl uninstall "${device_id}" "${BUNDLE_ID}" 2>/dev/null || true
  xcrun simctl install "${device_id}" "${APP}"
}

capture_iphone() {
  mkdir -p "${OUT_69}" "${OUT_65}" "${OUT_PREVIEW}"
  ensure_build_and_install "${IPHONE_DEVICE_ID}"

  echo "→ Capturing iPhone screenshots…"
  local i=1
  for screen in "${SCREENS[@]}"; do
    local name
    name=$(printf "%02d-%s.png" "${i}" "${screen}")
    capture_screen "${IPHONE_DEVICE_ID}" "${screen}" "${OUT_69}/${name}"
    # 6.5" App Store size (1284×2778)
    sips -z 2778 1284 "${OUT_69}/${name}" --out "${OUT_65}/${name}" >/dev/null
    i=$((i + 1))
  done

  echo "→ Recording App Preview (≈18s)…"
  local video_raw="${OUT_PREVIEW}/lune-preview-raw.mp4"
  local video_out="${OUT_PREVIEW}/lune-app-preview-6.9.mp4"
  rm -f "${video_raw}" "${video_out}"

  xcrun simctl io "${IPHONE_DEVICE_ID}" recordVideo --codec=h264 --force "${video_raw}" &
  local rec_pid=$!
  sleep 1

  for screen in splash today ask insights settings; do
    xcrun simctl terminate "${IPHONE_DEVICE_ID}" "${BUNDLE_ID}" 2>/dev/null || true
    xcrun simctl launch "${IPHONE_DEVICE_ID}" "${BUNDLE_ID}" \
      -AppStoreScreenshots \
      -ScreenshotScreen "${screen}" >/dev/null
    sleep 2.8
  done

  kill -INT "${rec_pid}" 2>/dev/null || true
  wait "${rec_pid}" 2>/dev/null || true

  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -i "${video_raw}" -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart "${video_out}" >/dev/null 2>&1
    rm -f "${video_raw}"
  else
    mv "${video_raw}" "${video_out}"
  fi
}

capture_ipad() {
  mkdir -p "${OUT_IPAD}"
  ensure_build_and_install "${IPAD_DEVICE_ID}"

  echo "→ Capturing 13-inch iPad screenshots…"
  local i=1
  for screen in "${SCREENS[@]}"; do
    local name raw
    name=$(printf "%02d-%s.png" "${i}" "${screen}")
    raw="${OUT_IPAD}/.${name}.raw.png"
    capture_screen "${IPAD_DEVICE_ID}" "${screen}" "${raw}"
    # Normalize to App Store Connect 13" iPad size (2064×2752)
    sips -z "${IPAD_TARGET_H}" "${IPAD_TARGET_W}" "${raw}" --out "${OUT_IPAD}/${name}" >/dev/null
    rm -f "${raw}"
    i=$((i + 1))
  done

  echo "→ Verifying iPad dimensions…"
  for f in "${OUT_IPAD}"/*.png; do
    sips -g pixelWidth -g pixelHeight "${f}" | paste - - -
  done
}

write_readme() {
  cat > "${OUT_ROOT}/README.md" <<'EOF'
# App Store marketing assets

Generated from the iOS Simulator with demo data (`-AppStoreScreenshots`).

## Screenshots

| Folder | Size | Use in App Store Connect |
|--------|------|--------------------------|
| `screenshots/6.9-iphone/` | native Pro Max | iPhone 6.9" / 6.7" slot |
| `screenshots/6.5-iphone/` | 1284×2778 | iPhone 6.5" slot |
| `screenshots/13-inch-ipad/` | 2064×2752 | 13-inch iPad slot |

Upload order suggestion:
1. Splash / brand
2. Today
3. Calendar
4. Ask Lumi
5. Insights
6. Settings

## App Preview

`preview/lune-app-preview-6.9.mp4` — short walkthrough (~15–20s).

App Store Connect → your iOS version → **App Previews and Screenshots**.

## Regenerate

```bash
./scripts/capture-app-store-screenshots.sh          # iPhone
./scripts/capture-app-store-screenshots.sh ipad     # 13-inch iPad
./scripts/capture-app-store-screenshots.sh all      # both
```
EOF
}

echo "→ Generating Xcode project…"
cd "${ROOT}"
xcodegen generate >/dev/null

case "${MODE}" in
  iphone)
    capture_iphone
    ;;
  ipad)
    capture_ipad
    ;;
  all)
    capture_iphone
    capture_ipad
    ;;
  *)
    echo "Usage: $0 [iphone|ipad|all]" >&2
    exit 1
    ;;
esac

write_readme

echo "✓ Done → ${OUT_ROOT}"
if [[ "${MODE}" == "iphone" || "${MODE}" == "all" ]]; then
  ls -la "${OUT_69}"
  ls -la "${OUT_PREVIEW}"
fi
if [[ "${MODE}" == "ipad" || "${MODE}" == "all" ]]; then
  ls -la "${OUT_IPAD}"
fi
