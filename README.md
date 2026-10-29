# Lumi website

Static site for Lumi, served by GitHub Pages at **https://mohammaddvi.github.io/LumiApp/**.

The app's source lives in a private repo (`LumiApp-source`). This folder is the source of truth for the site; `scripts/publish-website.sh` copies it to the public [`mohammaddvi/LumiApp`](https://github.com/mohammaddvi/LumiApp) repo, which only holds the website.

## App Store Connect URLs

| Field | URL |
|-------|-----|
| **Marketing URL** (shown as “Developer Website”) | `https://mohammaddvi.github.io/LumiApp/` |
| **Support URL** | `https://mohammaddvi.github.io/LumiApp/support.html` |
| **Privacy Policy URL** | `https://mohammaddvi.github.io/LumiApp/privacy.html` |

In-app constants live in `Cycle/App/LuneLegal.swift` and should match.

## Files

| File | Purpose |
|------|---------|
| `index.html` | Landing page |
| `support.html` | Contact + FAQ |
| `privacy.html` | Privacy policy |
| `PRIVACY_POLICY.md` | Same policy in Markdown |
| `styles.css` | Shared styles (light + dark, colors from `CycleTheme.swift`) |
| `assets/` | Icon, favicon, screenshots, social image |

When the App Store page is live, set the `href` on the App Store button in `index.html` and remove `aria-disabled`.

## Publish

```bash
./scripts/publish-website.sh
```
