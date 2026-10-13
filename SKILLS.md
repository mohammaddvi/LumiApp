# Skills

The project has local skills in `.agents/skills/` (gitignored, so they may be missing on a fresh clone). Before writing or reviewing code in one of the areas below, **read the matching `SKILL.md`** and follow it, then open its `references/` file if the task needs more detail.

## Project overrides

The skills are written for iOS 26 / Swift 6.3. This project targets **iOS 18.0, Swift 6.0, with `SWIFT_STRICT_CONCURRENCY: complete`** (see `project.yml`). When a skill disagrees with the points below, these win:

- Any API newer than iOS 18 must be wrapped in `if #available` with an iOS 18 fallback. Don't raise the deployment target.
- SwiftData stays local: `cloudKitDatabase: .none`. Health data never leaves the device.
- Any change to a `@Model` needs a new `VersionedSchema` and a stage in `LuneMigrationPlan` (`Cycle/Data/Persistence/LuneSchema.swift`). Don't edit `LuneSchemaV1` in place.
- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`), not XCTest.

## Which skill to read

| When the task involves… | Read |
|---|---|
| SwiftUI views, `@Observable`, `@State`/`@Environment`, view decomposition, previews | `.agents/skills/swiftui-patterns/SKILL.md` |
| Stacks, grids, `List`, `ScrollView`, `Form`, controls, search | `.agents/skills/swiftui-layout-components/SKILL.md` |
| `TabView`, `NavigationStack`, sheets, deep links | `.agents/skills/swiftui-navigation/SKILL.md` |
| `@Model`, `#Predicate`, `FetchDescriptor`, `@ModelActor`, schema migration | `.agents/skills/swiftdata/SKILL.md` |
| `async/await`, actors, `Sendable`, `@MainActor`, strict-concurrency errors | `.agents/skills/swift-concurrency/SKILL.md` |
| Writing or changing tests | `.agents/skills/swift-testing/SKILL.md` |
| Charts in Insights (Swift Charts) | `.agents/skills/swift-charts/SKILL.md` |
| `Codable`, the JSON export format (`HealthExportSnapshot`) | `.agents/skills/swift-codable/SKILL.md` |
| Keychain, file protection, CryptoKit | `.agents/skills/swift-security/SKILL.md` |
| Face ID app lock, `LAContext` flows | `.agents/skills/authentication/SKILL.md` |
| Local reminders, `UNUserNotificationCenter`, notification actions | `.agents/skills/push-notifications/SKILL.md` |
| VoiceOver, Dynamic Type, accessibility audits | `.agents/skills/ios-accessibility/SKILL.md` |
| Naming new types, methods and parameters | `.agents/skills/swift-api-design-guidelines/SKILL.md` |
| Structural changes: new layers, new modules, moving responsibilities | `.agents/skills/swift-architecture/SKILL.md` |
| UI/UX design, colors, type, motion, gestures, haptics, copy tone | "Design: fantasy theme" below first, then `.agents/skills/apple-design/SKILL.md` |

## Design: fantasy theme

MyLune is a **dreamy, moonlit storybook**, not a formal health app. It should feel like a gentle companion with a little magic, never like a medical form or a stock iOS settings screen. Read this section before any UI work; it overrides generic iOS styling and the apple-design skill's look.

### Look

- **Palette** (`Cycle/DesignSystem/CycleTheme.swift`): lavender mist by day, a starry night sky in dark mode. Lilac accent (`cycleSage`), rose for periods and emphasis (`cycleCoral`), star gold for ovulation (`cycleOvulation`), plum text. The token names are historical; always use the tokens, never hard-coded colors. `cycleMagic` is the lilac → rose gradient.
- **Backgrounds:** main tabs use `.fantasySkyBackground()` (gradient + twinkling sparkles, `DesignSystem/FantasySky.swift`). Sheets and long reading screens (chat, privacy policy) use plain `Color.cycleBackground` so text stays easy to read.
- **Type:** SF Rounded everywhere (set at the root with `.fontDesign(.rounded)`). No serif, no condensed or "corporate" type.
- **Shapes:** soft and round. Cards are `CycleCard` (26pt corners, lilac-tinted shadow). Primary actions are `PrimaryButtonStyle` pills (filled = magic gradient, outline = white pill). Avoid sharp corners, hairline dividers and dense grouped lists.
- **Lumi** (`DesignSystem/Lumi/`) is the app's heart. Show feelings through Lumi's expressions rather than icons or charts where it makes sense. Her color follows the feeling, or the cycle phase when no feeling is logged. Reuse `LumiView`; draw new poses or accessories in `LumiRenderer` rather than adding image assets.
- **Lumi holding a card:** `.lumiHolding(...)` makes Lumi peek over a card's top-trailing corner with her hands on its edge. Today uses it for the month calendar: she shows the logged feeling, or her guess (with a "?" bubble) from `FeelingForecastEngine`, and tapping her opens the feeling check-in. Leave room above the card for her head.
- **Lumi talking:** `LumiSpeech` + `LumiSpeechBubble` show a bubble whose text types out with Lumi's wordless babble (`LumiBabble`, synthesized chirps, ambient audio, respects the silent switch and the "Lumi's voice" setting). Keep lines short and kind, speak rarely (Today asks how you feel once a day and replies after a log), and let a tap on the bubble do the obvious thing. VoiceOver gets the text instead of the babble.
- **Magic accents:** four-point sparkles (`FantasySparkle`) and the `MagicBurst` celebration for meaningful moments (logging, completing something). Use them sparingly; one celebration per action.

### Feel

- Use `.agents/skills/apple-design/SKILL.md` for how the UI should **feel**: instant press feedback, interruptible spring motion and restraint. Ignore its advice to look like a default Apple app.
- That skill is written for the web (CSS, Pointer Events, Motion). Translate it to SwiftUI: `.spring(response:dampingFraction:)` for its damping/response values, `keyframeAnimator` for squash-and-stretch, `DragGesture` with velocity handoff for gestures, and `.sensoryFeedback` for haptics (`.selection` when choosing, `.success` when logging). Ignore its CSS and JS code.
- Idle motion (Lumi breathing, sparkles twinkling) is slow and subtle. Every animation must stop or become a simple fade when Reduce Motion is on; translucency must fall back to solid colors with Reduce Transparency.

### Voice

- Warm, playful and kind, like Lumi talking: "Rest is productive too." Short sentences, no jargon, no clinical tone, never alarming. Copy lives in `DesignSystem/LuneVoice.swift`.
- Never present predictions or AI answers as medical advice.

### Guardrails

- Contrast first: text must stay at least 4.5:1 (use `cycleText`/`cycleSecondary` on surfaces, `cycleOnAccent` on filled buttons). Check light and dark.
- Fantasy styling must never hide meaning: keep labels next to Lumi faces, keep VoiceOver labels, and keep Dynamic Type working (e.g. 3 → 2 columns at accessibility sizes).
