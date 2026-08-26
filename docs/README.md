# MyLune public site (GitHub Pages)

Static pages for App Store Connect **Privacy Policy URL** and **Support URL**.

## Enable GitHub Pages

1. Open the repo on GitHub: [mohammaddvi/LuneApp](https://github.com/mohammaddvi/LuneApp)
2. **Settings → Pages**
3. Under **Build and deployment → Source**, choose **Deploy from a branch**
4. Branch: **`main`** · Folder: **`/docs`**
5. Save. Wait a minute for the site to publish.

Site root: `https://mohammaddvi.github.io/LuneApp/`

## App Store Connect URLs

Paste these exactly:

| Field | URL |
|--------|-----|
| **Privacy Policy URL** | `https://mohammaddvi.github.io/LuneApp/privacy.html` |
| **Support URL** | `https://mohammaddvi.github.io/LuneApp/support.html` |
| **Marketing URL** | `https://github.com/mohammaddvi/LuneApp` |

Do **not** use the bare repo URL for Privacy or Support — Apple needs readable HTML pages.

In-app constants live in `Cycle/App/LuneLegal.swift` and should match the table above.

**Source repo:** [github.com/mohammaddvi/LuneApp](https://github.com/mohammaddvi/LuneApp)

## Files

| File | Purpose |
|------|---------|
| `index.html` | Marketing landing |
| `support.html` | Support + FAQ |
| `privacy.html` | Privacy policy (HTML) |
| `PRIVACY_POLICY.md` | Markdown source of truth |
| `styles.css` | Shared stylesheet |

Replace the App Store button `href="#"` on `index.html` when the product page is live.
