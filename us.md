# MintSnap: Card Value Scanner - iOS Development Guide

> **Source**: TR-20260917-卡牌扫描估值+操作指南.MD (translated & structured for LLM replication)
> **Target Market**: US App Store, English-only product
> **Report Date**: 2026-09-17 ｜ **Replication Date**: 2026-09-30

---

## 0. Naming & Metadata (App Store-verified)

| Item | Value |
|---|---|
| **App Name (≤30 chars)** | **MintSnap: Card Value Scanner** (24 chars) |
| **Subtitle (≤30 chars)** | **Scan. Grade. Worth. Instant.** (28 chars) |
| **Bundle Display Name** | MintSnap |
| **APP_NAME (code/project)** | MintSnap |
| **BUNDLE_ID** | com.zzoutuo.MintSnap |
| **MIN_IOS** | 17.0 |
| **Domain direction** | mintsnap.app |

**Positioning anchor (all marketing copy)**: *"The honest card scanner."* — Competitors give you a number; we give you a trustworthy number: real sold prices, graded-tier pricing, outlier removal, slab cert verification, transparent pricing.

**FORBIDDEN WORDS in app name/description/screenshots**: Pokemon, Poke, Charizard, PSA, eBay (third-party trademarks). The Keyword Field (100 chars) SHOULD use them: `pokemon,sports,card,scanner,psa,value,worth,price,tcg,grading,slab,grail,collection`.

**IAP Product IDs (from guide §6.8)**:
- `com.mintsnap.pro.monthly` — $7.99/mo (7-day free trial)
- `com.mintsnap.pro.yearly` — $49.99/yr (7-day free trial)
- `com.mintsnap.boost.cloud100` — $1.99 consumable (100 cloud scans)

**GLM Cloud Proxy (DEPLOYED & VERIFIED 2026-09-30)**:
- Worker URL: `https://cramjam-api.calcs.top` (backup: `https://cramjam-proxy.iocompile67692.workers.dev`)
- Auth (dev period): `{"userId": "<uuid>", "devKey": "cramjam-dev-2026"}` — production must switch to StoreKit 2 `appTransaction` JWS
- Payload passthrough: `{"model":"glm-5.3-flash","messages":[...],"thinking":{"level":"low"},"max_tokens":8192,"response_format":{"type":"json_object"}}`
- **Model behavior rules (MANDATORY)**: ① glm-5.3-flash ALWAYS thinks (cannot disable); set `"thinking":{"level":"low"}`. ② `max_tokens` must be generous — reasoning tokens count against completion budget; text ≥4096, vision/structured ≥8192, else `content` is empty with `finish_reason:"length"`. ③ Structured output via system prompt + `response_format json_object`; client ignores `reasoning_content`.
- Response shape: standard OpenAI-compatible `choices[0].message.content`.
- Worker errors: `401 invalid_receipt`, `402 insufficient_credits`, `400 bad_request`.
- BYO Key mode (user's own Z.ai/BigModel key): call `https://api.z.ai/api/paas/v4/chat/completions` directly, key stored in Keychain, never leaves device.

---

## 1. Executive Summary

**MintSnap = instant, trustworthy card-price engine + collection asset manager.**
Core loop ≤ 3 seconds: aim at card → snap → price appears (with confidence badge and graded-tier slider).

**Key differentiators** (vs LUDEX / CollX / Collectr / Eyevo / CardStock-Scanemon):
1. Three-engine recognition: on-device Vision OCR + on-device feature-print gallery retrieval + GLM-5.3-Flash cloud fallback with confidence gating (<0.85 → cloud).
2. "Proof by image" result UI: official card image always shown next to result; one-tap correction from Top-3 candidates.
3. **Price Health System** (industry first): multi-source cross-check + MAD outlier removal + High/Medium/Low confidence labels + per-source attribution links.
4. Graded-tier pricing: PriceCharting native Ungraded/G7/G8/G9/G9.5/PSA10 six tiers + cross-grader conversion matrix (PSA/BGS/SGC/CGC).
5. Cert verification: OCR slab label cert number → one-tap deep link to official PSA/BGS/CGC lookup → "Cert Verified" badge.
6. Grading ROI calculator: raw price + grading fee + expected tier price + shipping → net profit + Worth-it/Skip-it verdict.
7. Honest monetization: transparent pricing page, no lifetime purchase, no deceptive subscription, CSV/JSON export free.

---

## 2. Competitive Analysis

| App | Strengths | Weaknesses | Our Advantage |
|-----|-----------|------------|---------------|
| CardStock + Scanemon ($9.99/mo, 10 free/mo) | Established brand | Unstable recognition, delayed prices, no graded-tier pricing | 3-engine recognition, 6-tier graded pricing, price health labels |
| LUDEX ($4.99/mo, 10 free/mo) | Sports card focus | No grade-tier pricing (PSA10 $1200 vs PSA9 $450 undistinguished); 25–30% sports card miss rate | Native tiered prices + cross-grader matrix; higher recognition |
| CollX (Pro $9.99/mo) | Large community | "Only 1 of 20 scans identified"; inaccurate prices behind $10/mo paywall | Free tier works 5×/day; verification-first UI |
| Collectr (free + €4.64/mo) | Portfolio tools | Bad eBay PSA Vault pulls crash graded prices; no Cardmarket | MAD outlier removal + multi-source cross-check |
| Eyevo (freemium) | <1s scan, 96% accuracy, slab ID, JP cards | No cert verify, no grading ROI, no price health, no BYO AI | Full trust layer (P3/P4/P5/P6) + BYO GLM Key |
| PSA Official App | Free + grading bundle | PSA ecosystem only | Multi-grader support |

**Pain points → features (all backed by real user quotes)**:
- P1 low recognition → 3-engine + confidence gating
- P2 right card wrong variant → forced official-image comparison + Top-3 correction
- P3 sold vs listing price confusion → Price Health System
- P4 graded cards priced as one blob → 6-tier native prices + auto slab tier switch
- P5 fake slabs → Cert verification deep links
- P6 "should I grade?" → ROI calculator ($50 rule calibrated)
- P7 Japanese cards missing → TCGdex JP/CN data + GLM fallback
- P8 deceptive subscriptions → transparent pricing, one-tap cancel guidance
- P9 no collection loop → Binder + asset curve + alerts + CSV/JSON export

---

## 3. ⚠️ Feature Inventory (MANDATORY)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---------|--------------------|------------|------------|-------------|-------------|---------------------|
| 1 | Camera Scan Pipeline | 1. Launch (no signup/onboarding) → camera opens → 2. Aim at card → rectangle lock haptic tick → 3. Auto shutter → result ≤0.8s | Camera frames (AVCaptureSession) | VNDetectRectanglesRequest card crop → VNRecognizeTextRequest OCR → VNGenerateImageFeaturePrint gallery similarity | Cropped card image + OCR lines + confidence + isSlab + certNumber | In-memory scan session | Card frame detected <0.3s on iPhone; OCR extracts name/number; result in ≤0.8s |
| 2 | Confidence Gating + GLM Cloud Fallback | Automatic: confidence ≥0.85 → local result; <0.85 → cloud scan (consumes 1 credit, with visible notice) | Cropped card JPEG (base64) | GLM-5.3-Flash vision → structured CardIdentity JSON; timeout 12s, 1 retry, graceful degrade to local candidates + manual search | CardIdentity (name/set/number/variant/grade/cert) or fallback candidates | None (scan session) | Low-confidence samples resolve via cloud ≥95%; GLM failure → local candidates + no credit charged |
| 3 | Result Card with Proof-by-Image | 1. Result sheet slides up → 2. Official card image left, price right → 3. User verifies match | CardIdentity | TCGdex search → Top-3 candidates with official images | Result card: price rolling animation 0→value (0.4s), confidence badge, tier slider; >$100 triggers gold particles + heavy haptic | On save → SwiftData CardRecord | Official image ALWAYS visible; Top-3 correction completes in ≤2s |
| 4 | One-Tap Correction | 1. Tap "Not this card?" → 2. Top-3 candidate grid (image+set) → 3. Tap to swap; if all wrong → "Scan again with AI" | User tap | Re-match price service to new candidate | Updated result card | Same as #3 | Correction ≤2s; AI rescan consumes 1 cloud credit with free-tier notice |
| 5 | Graded-Tier Pricing | Auto: slab detected → Graded tab → tier price for that grade; horizontal tier slider Ungraded/7/8/9/9.5/PSA10 | PriceCharting product id | TieredPrice fetch (6 fields); missing tiers interpolated via CrossGraderMatrix (GLM-assisted, configurable coefficients, e.g. SGC10≈PSA10×0.75) | Six-tier price strip + active tier highlight | PriceSnapshot history | All 6 tiers displayed when available; slab auto-switches to matching tier |
| 6 | Price Health System | Automatic on every price display | ≥90-day sales series from PriceCharting/multi-source snapshots | MAD outlier removal (median ± 3×1.4826×MAD) → cross-source variance check | HIGH (<15% spread) / MEDIUM (15–40%) / LOW (>40% or <3 sales, with reason text) label + source links + timestamp | PriceSnapshot (source, tier, fetchedAt, salesCount) | Artificial outliers 100% flagged; LOW always shows reason; >7-day-old prices show "stale" gray badge and auto-refresh |
| 7 | Cert Verification | 1. Slab detected → result bottom [Verify Cert] → 2. SFSafariView opens official lookup → 3. Return → user marks Match/No match | Grader (PSA/BGS/CGC/SGC) + cert# (8–10 digits OCR) | Deep link build: PSA psacard.com/cert/{cert}; BGS beckett.com lookup; CGC cgccards.com/certlookup/{cert}/ | "Cert Verified" badge on result card | Badge flag on CardRecord | All three deep links open correctly; badge persists |
| 8 | Grading ROI Calculator | 1. Raw card result → [Should I grade it?] → 2. Grading fee preset (PSA $25 / BGS / SGC) + shipping → 3. Verdict | Raw price, grading fee, expected grade tier prices | Net = expected tier price − grading fee − shipping − raw opportunity; $50-rule calibrated threshold | Net profit/loss + binary "Worth it / Skip it" verdict | None (transient) | Verdict binary and consistent with $50 rule; editable fee presets |
| 9 | Collection Binder | 1. Tap Binder tab → 2. Card grid with images/prices → 3. Total asset curve at top → 4. Tap card for detail + delete | Saved CardRecords | SwiftData fetch + aggregate valuation over time | Binder grid, total value chart, per-card price history | SwiftData + CloudKit sync | 500-card binder scrolls smoothly; two-device sync <5s |
| 10 | Price Alerts | 1. Card detail → Add Alert → 2. Threshold → 3. Background poll triggers local push | Card id + threshold | BGTaskScheduler daily poll via PriceCharting; threshold compare | Local push "Charizard ex crossed $50" | SwiftData AlertRule; 5 free / unlimited Pro | Alerts fire accurately; free tier capped at 5 |
| 11 | Weekly Collection Pulse Push | Sunday 8pm local: "Your collection gained +$128 this week. Top mover: … +14%" | Week-over-week valuations | Aggregation; on iOS 26 summary text via Apple FoundationModels (free on-device); fallback template text | Local push | None | Push arrives Sundays; copy matches format |
| 12 | StoreKit 2 Paywall + Quota Ledger | 1. Free 6th scan → soft wall (result shown; save/tier/alerts locked) → Paywall → 2. Purchase → credits/quota updated | StoreKit 2 products | Entitlements + consumable credits ledger; free 5 on-device scans/day; Pro unlimited on-device + 30/mo cloud (monthly) or 60/mo (yearly); Boost +100 cloud; BYO Key = unlimited cloud | Unlocked features + credit balance | UserDefaults/SwiftData quota ledger + Keychain receipts | Sandbox purchase/restore/expire no deadlock; ledger prevents overdraw |
| 13 | BYO GLM Key Mode | 1. Settings → AI → paste Z.ai/BigModel key → 2. Cloud scans unlimited (user's cost) | User key | Stored in Keychain (iCloud Keychain sync); requests go direct to api.z.ai | Unlimited cloud recognition | Keychain | Key never leaves device/Keychain; direct call verified |
| 14 | CSV/JSON Export | Binder → Export → share sheet | All CardRecords + snapshots | Serialize | CSV and JSON files via ShareLink | Files app / share target | Free tier can export; data not locked in |
| 15 | Apple FoundationModels Insights (iOS 26+) | Binder → Insights; result interpretation, collection insights, grading advice wording, condition notes | CollectionStats | `if #available(iOS 26,*)` LanguageModelSession with @Generable PulseSummary | Headline + top mover + grading advice | None | Free, offline; gracefully nil on iOS<26 |
| 16 | iCloud Sync (optional) | Settings toggle → CloudKit sync of binder | SwiftData records | CloudKitContainer sync | Same data on all devices | CloudKit | Toggle on/off works; conflicts last-write-win |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail | Interaction |
|---|--------|-------------|--------|-------------|
| 1.1 | Scan | Auto shutter | Auto-capture when frame stable | automatic |
| 1.2 | Scan | Card lock haptic | light tick on rectangle lock | haptic |
| 1.3 | Scan | Batch continuous scan | After save, stay in camera; next card continues (supermarket gun mode) | automatic |
| 2.1 | GLM fallback | Cloud upload consent | Card image upload on fallback; toggleable in Settings ("on-device only" switch) | setting |
| 3.1 | Result | 3D card lift animation | rotation3DEffect 0.3s on result | animation |
| 3.2 | Result | Price roll | 0→value 0.4s, monospacedDigit 44pt heavy rounded | animation |
| 3.3 | Result | Gold particles | >$100 cards, ≤1.5s, Metal/particle effect + heavy CoreHaptics AHAP | animation+haptic |
| 3.4 | Result | Save swipe | Right-swipe saves with success double-tap haptic, +1 binder, seamless next scan | gesture |
| 5.1 | Tiered price | Slab auto-switch | PSA/BGS/CGC/SGC label detected → auto Graded tab | automatic |
| 6.1 | Health | Stale pricing | >7 days → gray "stale" badge + auto refetch | automatic |
| 8.1 | ROI | Fee presets | PSA $25/BGS/SGC editable | input |
| 12.1 | Paywall | Soft wall | Free 6th scan shows result but locks save/tier/alerts | UI gate |
| 12.2 | Paywall | Trial-end nudge | 48h before trial end push: "Your binder stats this week: +$212. Keep tracking?" | push |
| 14.1 | Export | CSV/JSON both | Both formats, free | share |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|---|--------|--------|-------------|---------|
| Scan → Result | #1/#2 | #3 | CardScanResult/CardIdentity + cropped image | scan completes |
| Result → Binder | #3 | #9 | CardRecord on save | user saves/swipes |
| Binder → Alerts | #9 | #10 | card id + current price | user adds alert |
| Binder → Pulse | #9 | #11 | weekly valuation delta | Sunday 8pm |
| Quota → Scan | #12 | #2 | cloud credits available | low-confidence scan |
| Slab → Tier | #1 | #5 | isSlab + grader + grade | slab detected |
| Cert → Badge | #7 | #3/#9 | verified flag | user confirms match |
| ROI → Result | #8 | #3 | verdict display | user taps calculator |
| Export ← Binder | #9 | #14 | all records | user exports |

**VERIFICATION**: 16 primary features + 14 sub-features cover every capability in the Chinese guide (P1–P9 pain points all mapped). ✅

---

## 4. Apple Design Guidelines Compliance

- **Liquid Glass dark theme (iOS 26 style)**: dark-first (dark-room card viewing is the real collector scenario; holo shine pops on dark). Mint green `#00D68F` primary ("arrival green" + name tie-in), card gray-gold accents. Light theme also supported.
- **Single-hand priority**: camera 65% of screen; results in Bottom Sheet (iOS convention); tabs `Scan / Binder / Alerts / Pro` (≤4).
- **Typography**: SF Pro; prices `.system(size:44,weight:.heavy,design:.rounded).monospacedDigit()`.
- **Motion budget**: ≤3 animations per result (card lift 0.3s → price roll 0.4s → badge pop 0.2s); never slow batch scanning.
- **Haptics**: frame lock = light tick; shutter = medium; save = success double-tap; PSA10/Gem = heavy custom AHAP bundled.
- **Copy tone**: US card-community voice, short, number-first: `PSA 10 · $1,250 · HIGH confidence`. USD prefix, thousands separators.
- **Accessibility**: VoiceOver reads "Charizard ex, Scarlet and Violet 151, raw price 42 dollars, confidence high"; Dynamic Type full; both themes.
- **Privacy**: card images not uploaded by default (GLM fallback uploads cropped image, toggleable in Settings); PrivacyInfo.xcprivacy filled truthfully.

## ⚠️ App Store Compliance — AI Features

This app uses cloud AI (GLM-5.3-Flash via proxy or BYO Key) for card identification, and Apple FoundationModels (iOS 26, free on-device) for interpretation/copy.

- **iOS 26+**: FoundationModels powers insights free out-of-the-box (`if #available(iOS 26,*)` wrapped; older devices skip gracefully).
- **Guideline 2.1(a)**: never show dead AI buttons; cloud fallback must degrade gracefully to local candidates + manual search (guide iron rule #4: GLM timeout/overdraft → fallback, scan credit NOT charged).
- **No free-generation counting dead code**: cloud credits are a real metered cost tied to consumable/subscription — this is a metered-utility model, NOT the banned "free generations then paywall" pattern. Credits ledger must be honest and visible.
- **Create `app_review_info.md`** explaining: dev proxy mode used during review, BYO Key instructions for reviewers.
- **Privacy**: image upload consent toggle in Settings; PrivacyInfo.xcprivacy declares it.

## ⚠️ App Store Compliance — Subscriptions

Paywall MUST contain (Guideline 3.1.2(c)):
- Functional Privacy Policy link + Terms of Use (EULA) link
- Subscription title, length, price for each tier
- Auto-renewal disclosure text
- Transparent pricing page shown pre-purchase (this is the app's core differentiator — "The honest card scanner")
- One-tap cancel guidance (Settings → shows Manage Subscriptions deep link)
- **No lifetime purchase** (products contain monthly cloud costs) — marketing line: "We don't sell lifetime because we pay for your AI scans every month — and we'd rather stay honest than go broke."

---

## 5. Technical Architecture

- **Language**: Swift 6 + SwiftUI, MV + environment-injected `@Observable` service singletons. NO network/recognition logic inside Views.
- **Min iOS**: 17.0 (FoundationModels features `if #available(iOS 26,*)`).
- **Money**: Int cents everywhere internally; Double only at display. Dates stored UTC, displayed local.
- **Every external API**: 3s timeout + 1 retry + graceful degradation UI.
- **Secrets**: GLM/PriceCharting tokens only on the Cloudflare Worker proxy; app stores no keys (BYO Key exception → Keychain).

### Three-layer recognition + three-source prices
```
[Camera AVCaptureSession]
 → L1 Vision rectangle detect + crop
 → L2 on-device: OCR (en-US, ja-JP, zh-Hans; usesLanguageCorrection=false) + FeaturePrint gallery NN retrieval
 → Confidence gate: ≥0.85 → local; <0.85 → L3 GLM-5.3-Flash (proxy, base64 crop → structured JSON)
 → Candidate match: TCGdex search + gallery ranking → Top-3
 → Human confirm (official image) / one-tap correct
 → Price: PriceCharting (tiered) + TCGdex (metadata) [+ eBay Browse v1.1 optional]
 → Price Health: MAD outlier removal + cross-source variance → High/Med/Low
 → SwiftUI result → SwiftData → CloudKit
 → AlertEngine: BGTaskScheduler daily poll → local push
```

## 6. Module Structure

```
MintSnap/
├── App/                 MintSnapApp.swift, RootRouter
├── Scan/                ScanEngine, CameraView, SlabDetector, CardGallery
├── AI/                  GLMClient (proxy + BYO direct), ProxyClient, FoundationModelsService
├── Price/               PriceChartingService, TCGdexService, PriceHealthEngine,
│                        CrossGraderMatrix, GradeROICalculator
├── Models/              Card, PriceSnapshot, Collection, AlertRule, ScanQuota (SwiftData)
├── Features/            ResultCardView, BinderView, AlertsView, CertVerifyView,
│                        ROICalculatorView, PaywallView, SettingsView
├── Store/               StoreService (StoreKit2), ScanQuota ledger
├── Sync/                CloudKitContainer
└── Resources/           PrivacyInfo.xcprivacy, Assets, Localizable (English only)
```

## 7. ⚠️ Data Flow Diagrams (per feature)

```
Feature: Scan + Identify
User Input: camera frame
 └ CameraView → ScanEngine.process(pixelBuffer)
    └ L1 rectangle crop → L2 OCR + gallery score → CardScanResult(confidence, isSlab, cert)
       └ confidence<0.85? → GLMClient.identifyCard(base64) via proxy (credits−1, visible notice)
          └ CardIdentity JSON (name/set/number/variant/graded/grader/grade/cert)
Display: ResultCardView bottom sheet (official image + rolling price + badges)

Feature: Price Resolution
Input: confirmed CardIdentity
 └ PriceChartingService.fetch(productId/query) → TieredPrice(6 tiers)
 └ TCGdexService.search/metadata → official image + set info
 └ missing tier? → CrossGraderMatrix interpolate (GLM-assisted)
 └ PriceHealthEngine.evaluate(sales90d) → HIGH/MEDIUM/LOW + reason
Persistence: PriceSnapshot(source,tier,fetchedAt,salesCount,value)
Display: tier slider + health badge + source links + timestamp; stale>7d auto refetch

Feature: Save to Binder
Input: user swipe/tap save
 └ CardRecord(image, identity, price, tier, health, verifiedFlag) → SwiftData
 └ CloudKit sync (if enabled)
Display: BinderView grid + total asset curve; VoiceOver full readout

Feature: Quota & Paywall
Input: scan events / purchases
 └ ScanQuota ledger: free 5 on-device/day; Pro unlimited on-device + 30|60 cloud/mo; Boost +100
 └ StoreService: StoreKit2 Transaction.currentEntitlements + finish()
Display: PaywallView (transparent pricing, legal links, auto-renew text)

Feature: Alerts
Input: AlertRule(card, threshold)
 └ BGTaskScheduler daily → PriceCharting poll → threshold crossed?
Display: local push; AlertsView list with on/off toggles
```

**Iron rules (code law)**:
1. Identification results ALWAYS show official card image for human verification.
2. Every price carries source/tier/fetchedAt/salesCount; >7 days → "stale" + auto refetch.
3. LOW health must display its reason. Never a silent number.
4. Cloud failure → graceful degrade to local candidates + manual search; credit NOT charged.

## 8. Implementation Flow (8 weeks MVP)

1. W1: Project skeleton + camera/Vision scan pipeline (frame detect <0.3s, OCR name/number)
2. W2: TCGdex/PriceCharting integration + result card UI (≥90% on 100-card clean test set)
3. W3: GLM fallback + confidence gating + correction UI (fallback success ≥95%, P95 ≤4s)
4. W4: Price health + tiered pricing + cross-grader matrix (artificial outliers 100% flagged)
5. W5: SwiftData + CloudKit + Binder + batch scan (500 cards smooth; sync <5s)
6. W6: StoreKit2 + quota ledger + paywall + transparent pricing page (sandbox full pass)
7. W7: Alert engine (BGTask+push) + Cert verify + ROI calculator
8. W8: Polish (motion/haptics/VoiceOver) + TestFlight (crash-free ≥99.8%)

## 9. UI/UX Design Specifications

- **Color**: dark theme primary; Mint `#00D68F`, background near-black, card gray-gold accents; light theme included.
- **Layout**: camera 65% viewport; bottom-sheet results; 4 tabs max.
- **Animation budget**: card lift 0.3s → price roll 0.4s → badge pop 0.2s; gold particles ≤1.5s.
- **Haptics**: as §4; CoreHaptics AHAP file bundled for PSA10 moment.
- **Numbers**: monospacedDigit; `$` prefix; thousands separators.

## 10. Code Generation Rules

- Swift 6, SwiftUI; `@Observable` services via Environment; no logic in Views.
- Int cents; UTC storage; local display.
- 3s timeout + 1 retry + graceful degrade for every external API.
- No third-party networking/SDK dependencies unless essential; Apple-native first.
- GLM call contract: proxy `POST https://cramjam-api.calcs.top` body `{userId, devKey(dev), payload}`; payload `{model:"glm-5.3-flash", messages, thinking:{level:"low"}, max_tokens:8192(vision)/4096(text), response_format:{type:"json_object"}}`; parse `choices[0].message.content`; ignore `reasoning_content`; handle 401/402.
- BYO mode: direct `https://api.z.ai/api/paas/v4/chat/completions` with `Authorization: Bearer <key>` from Keychain.
- PriceCharting via proxy path `/pc/...` (token server-side only); TCGdex direct `https://api.tcgdex.net/v2/en/cards?name=...`.
- Privacy: image upload off by default except fallback; Settings toggle "On-device recognition only".

## 11. Build & Deployment Checklist

- [ ] Free-tier cold start → first card priced ≤8s
- [ ] On-device ≥90% (100 clean samples); <0.85 confidence → GLM with visible credit charge
- [ ] Result always shows official image + Top-3 one-tap correction
- [ ] Ungraded/7/8/9/9.5/PSA10 six tiers; slab auto-switches tier
- [ ] Every price: source + timestamp + health label (LOW shows reason)
- [ ] MAD logic matches spec (median ± 3×1.4826×MAD)
- [ ] Cert deep links (PSA/BGS/CGC) open; Verified badge persists
- [ ] ROI calculator: fee/shipping/expected tier, binary verdict
- [ ] StoreKit2 sandbox: all products purchase/restore/expire cleanly; BYO Key in Keychain
- [ ] Free 5/day; Pro unlimited on-device; cloud ledger no overdraw
- [ ] CSV/JSON export free; iCloud sync toggleable
- [ ] VoiceOver completes full scan-save flow
