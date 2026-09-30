# Pricing Configuration

## Monetization Model: Subscription (IAP) + Consumable Boost

MintSnap uses transparent auto-renewable subscriptions (monthly/yearly, 7-day free trial) plus a consumable cloud-scan boost pack. NO lifetime purchase exists — Pro includes ongoing monthly cloud AI scan costs, and the brand promise is "We'd rather stay honest than go broke."

## Subscription Group
- **Group Name**: MintSnap Pro
- **Reference Name**: MintSnap Pro
- **Products in group**: com.mintsnap.pro.monthly, com.mintsnap.pro.yearly

## Subscription Tiers (Auto-Renewable)

### 1. Monthly Subscription
- **Reference Name**: MintSnap Pro Monthly
- **Product ID**: `com.mintsnap.pro.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $7.99 USD per month
- **Display Name**: `MintSnap Pro Monthly` (19 chars, ≤35 ✅)
- **Description**: `Unlimited scans, 6-tier prices, 30 cloud AI scans/mo` (52 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: MintSnap Pro
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription (Primary — pre-selected in paywall)
- **Reference Name**: MintSnap Pro Annual
- **Product ID**: `com.mintsnap.pro.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $49.99 USD per year (≈$4.17/mo, 48% savings vs monthly)
- **Display Name**: `MintSnap Pro Annual` (19 chars, ≤35 ✅)
- **Description**: `Best value: everything in Pro + 60 cloud AI scans/mo` (52 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: MintSnap Pro (same group as monthly)
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Consumable)

### 1. AI Boost Pack
- **Reference Name**: MintSnap AI Boost 100
- **Product ID**: `com.mintsnap.boost.cloud100`
- **Type**: Consumable (cloud scan credits, never expire)
- **Price**: $1.99 USD
- **Display Name**: `AI Boost: 100 Scans` (19 chars, ≤35 ✅)
- **Description**: `100 cloud card identifications, never expire` (43 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: N/A (consumables cannot be restored; balance shown in app)

## BYO Key Mode: Premium Features Unlock

### Free Tier (with own GLM API key)
- Cloud card identification: ✅ Unlimited (user's own Z.ai/BigModel key, stored in Keychain)
- Basic scanning: ✅ 5 on-device scans/day (quota applies regardless of key)
- The subscription unlocks APP features, not AI usage for BYO users.

### Free Tier (Default)

- **Price**: Free
- **Features**:
  - 5 on-device scans per day
  - Ungraded price tier only
  - Collection binder up to 50 cards
  - CSV/JSON export
  - No price alerts
  - No graded-tier pricing (soft wall: 6th scan shows result but locks save/tier/alerts)
- **Conversion hooks**:
  - Soft wall: results always shown; only saving, tiered prices, and alerts are locked (never block seeing the value)
  - Trial-end nudge 48h before expiry: "Your binder stats this week: +$212. Keep tracking?" — asset data, not feature fear

## Pro Features Unlocked (All Paid Tiers)

| Feature | Free | Pro (All Paid Tiers) |
|---------|:----:|:--------------------:|
| On-device scans | 5/day | ✅ Unlimited |
| Graded 6-tier pricing (Ungraded/7/8/9/9.5/10) | ❌ | ✅ |
| Cross-grader conversion matrix | ❌ | ✅ |
| Cert verification (PSA/BGS/CGC deep links) | ❌ | ✅ |
| Price health labels (High/Med/Low) | Ungraded only | ✅ |
| Price alerts | ❌ | ✅ 5 (monthly) / Unlimited (yearly) |
| Collection binder | ≤50 cards | ✅ Unlimited |
| Batch continuous scanning | ❌ | ✅ |
| Cloud AI fallback scans | ❌ | ✅ 30/mo (monthly) / 60/mo (yearly) |
| CSV/JSON export | ✅ | ✅ |
| iCloud sync toggle | ✅ | ✅ |

## Free Trial
- **Duration**: 7 days
- **Type**: Free trial (auto-converts to paid subscription)
- **Available for**: Both monthly and yearly tiers

## Policy Pages Required
- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (REQUIRED — subscription apps must have Terms)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist
- [x] Auto-renewal terms will be included in Terms of Use
- [x] Cancellation instructions will be included in Support Page
- [x] Pricing clearly stated in PaywallView (transparent pricing page, pre-purchase visible)
- [x] Free trial terms included (7 days, both tiers)
- [x] Restore purchases functionality implemented
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options
- [x] No lifetime purchase (ongoing cloud costs; honest narrative instead)
- [x] No competitor price references anywhere in the app
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] IAP type purity: subscriptions separated from consumable boost pack
