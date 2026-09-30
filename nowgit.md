# Git Repositories

## Main App (iOS Application)

| Item | Value |
|------|-------|
| **Repository Name** | MintSnap |
| **Git URL** | git@github.com:asunnyboy861/MintSnap.git |
| **Repo URL** | https://github.com/asunnyboy861/MintSnap |
| **Visibility** | Public |
| **Primary Language** | Swift |
| **GitHub Pages** | ✅ **ENABLED** (from `/docs` folder) |

## Policy Pages (Deployed from Main Repository /docs)

| Page | URL | Status |
|------|-----|--------|
| Landing Page | https://asunnyboy861.github.io/MintSnap/ | ✅ Active |
| Support | https://asunnyboy861.github.io/MintSnap/support.html | ✅ Active |
| Privacy Policy | https://asunnyboy861.github.io/MintSnap/privacy.html | ✅ Active |
| Terms of Use | https://asunnyboy861.github.io/MintSnap/terms.html | ✅ Active |

## Repository Structure

```
MintSnap/
├── MintSnap.xcodeproj/            # Xcode Project (xcodegen-managed)
├── MintSnap/                      # iOS App Source Code
│   ├── App/                       # MintSnapApp, theme colors
│   ├── Scan/                      # CameraView, ScanEngine, ScanViewModel
│   ├── AI/                        # GLMClient, QuotaService, InsightsService
│   ├── Price/                     # PriceServices, AlertEngine
│   ├── Models/                    # CardRecord, PriceSnapshot, AlertRule (SwiftData)
│   ├── Features/                  # ScanView, ResultCardView, BinderView, AlertsView,
│   │                              #   PaywallView, SettingsView, CertVerifyView,
│   │                              #   ROICalculatorView, RootTabView
│   ├── Store/                     # StoreService (StoreKit 2)
│   ├── Info.plist                 # Camera usage, BGTask identifiers
│   └── Assets.xcassets            # App icon
├── docs/                          # Policy Pages (GitHub Pages source) — PHASE 7
│   ├── index.html
│   ├── support.html
│   ├── privacy.html
│   └── terms.html
├── .github/workflows/
│   └── deploy.yml
├── us.md                          # English implementation guide
├── capabilities.md
├── icon.md
├── price.md
├── project.yml
├── nowgit.md
├── TR-20260917-卡牌扫描估值+操作指南.MD   # Original Chinese guide
├── GLMProxySecret.txt             # ⚠️ EXCLUDED from repo (.gitignore — dev proxy key)
├── PriceChartingSecret.txt        # ⚠️ EXCLUDED from repo (.gitignore — API token)
├── keytext.md                     # ⚠️ EXCLUDED from repo (.gitignore — confidential ASO strategy)
└── COMPETITOR_REPORT.md           # ⚠️ EXCLUDED from repo (.gitignore — confidential competitor analysis)
```

## Security Notes

- `MintSnap/AI/GLMProxySecret.txt` (GLM proxy dev key) is gitignored and NOT tracked in the repository.
- `MintSnap/Price/PriceChartingSecret.txt` is gitignored (file absent on disk — app gracefully falls back to TCGdex pricing).
- `.env`, `keytext*.md`, `COMPETITOR_REPORT.md`, icon source files are gitignored.
- The dev-period proxy credential (`cramjam-dev-2026`) appears in documentation files only as published in the user's own GLM-Cloudflare repo; it is test-only and must be removed before production (see GLM-Cloudflare guide §6).
