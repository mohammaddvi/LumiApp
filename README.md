# Lune

Local-first, privacy-first period & cycle tracker for iOS. Named for the moon.

Cycle logs, check-ins, preferences, chat history, and Gemma inference all stay on device. There is no Lune health cloud in this release.

## Requirements

- Xcode 16+ (Swift 6)
- iOS 18+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional if you use the committed `Cycle.xcodeproj`)

## Clone & open

```bash
git clone https://github.com/YOUR_USERNAME/PeriodApp.git
cd PeriodApp
xcodegen generate   # sync project.yml → Cycle.xcodeproj after pulling changes
open Cycle.xcodeproj
```

Run the **Cycle** scheme — the home-screen name and icon show as **Lune**.

### Signing

`project.yml` includes a `DEVELOPMENT_TEAM` for local builds. Replace it with your Apple Developer team ID, or set **Signing & Capabilities** in Xcode after opening the project.

## Push to GitHub

If you created this repo locally and need a remote:

```bash
gh auth login
gh repo create PeriodApp --private --source=. --remote=origin --push
```

Use `--public` instead of `--private` if you want a public repository. The first push includes the app source, tests, privacy policy, and Xcode project — not on-device model weights (`.litertlm` files are gitignored).

## Local AI (Gemma 4)

1. **Settings → Local AI (Gemma 4)**
2. Tap **Download Gemma 4** (~2.6 GB; Wi‑Fi recommended)
3. Use the **Ask** tab after the model loads

You can also place a `.litertlm` file in **Files → On My iPhone → Lune → Models**.

## Production / App Store checklist

### Already in the project

| Item | Status |
|------|--------|
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | ✅ No tracking, required-reason APIs declared |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` |
| Usage descriptions | ✅ Face ID, notifications |
| In-app privacy policy | ✅ Settings → Privacy policy |
| Medical disclaimer | ✅ Settings → About |
| Increased Memory Limit entitlement | ✅ For on-device Gemma |
| App category | ✅ Health & Fitness |

### You must do before submission

1. **Privacy Policy URL (required)**  
   Apple requires a **public HTTPS URL** in App Store Connect, even for local-only apps.  
   - Host `docs/PRIVACY_POLICY.md` (GitHub Pages, your site, Notion public page, etc.)  
   - Update `LuneLegal.privacyPolicyURL` in `Cycle/App/LuneLegal.swift` to match  
   - Enter the same URL in **App Store Connect → App Information → Privacy Policy URL**

2. **Support URL (required)**  
   - Set up `https://…/support` or a mailto/support page  
   - Update `LuneLegal.supportURL` and **App Store Connect → Support URL**

3. **App Privacy questionnaire (App Store Connect)**  
   For this build (no Lune server, no analytics):
   - **Data Not Collected** — if you do not receive health data on your servers  
   - Disclose in the policy that optional Hugging Face downloads use their servers  
   - No tracking, no advertising

4. **Age rating**  
   Complete the questionnaire honestly (health / cycle tracking content).

5. **Screenshots & metadata**  
   - 6.7" and 6.5" iPhone screenshots minimum  
   - Subtitle, description, keywords  
   - Mention: local-only, not medical advice, optional AI download

6. **Archive & upload**

```bash
xcodegen generate
xcodebuild -scheme Cycle -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=23PXPK4JQ6 archive \
  -archivePath build/Lune.xcarchive
```

Then **Xcode → Organizer → Distribute App → App Store Connect**.

7. **TestFlight** — internal test on device, then submit for review.

### Privacy policy — do you need one?

**Yes.** App Store Connect requires a privacy policy URL for apps that handle health-related or personal data. Lune also includes an in-app copy under **Settings → Privacy policy** so users can read it without leaving the app.

## Architecture

- **SwiftData** — cycles, flow, check-ins, preferences (local only, no CloudKit sync)
- **Schema versioning** — `LuneSchemaV1` + `LuneMigrationPlan` for lightweight migrations on future updates
- **Automatic backups** — timestamped copy of the store before each launch (`Application Support/Cycle/Backups/`)
- **Stable store path** — `Application Support/Cycle/cycle.store` (never rename after 1.0)
- **Ask Lune** — on-device Gemma via LiteRT-LM
- **Notifications** — local only (UNUserNotificationCenter)

### Adding a schema change in a future update

1. Create `LuneSchemaV2` with the new models/properties (prefer optional fields + defaults).
2. Add it to `LuneMigrationPlan.schemas`.
3. Add `MigrationStage.lightweight(fromVersion: LuneSchemaV1.self, toVersion: LuneSchemaV2.self)`.
4. Test migration from a V1 store copy before shipping.
