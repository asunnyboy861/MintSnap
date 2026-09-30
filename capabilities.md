# Capabilities Configuration

## Analysis
Based on operation guide analysis:
- Camera scanning (AVCaptureSession) → NSCameraUsageDescription
- In-App Purchase (StoreKit 2 subscriptions + consumable) → IAP capability
- Background tasks (BGTaskScheduler price polling) → Background Modes (processing)
- Local notifications (price alerts, weekly pulse) → local notifications (no capability needed)
- CloudKit sync (optional toggle) → iCloud capability (partial manual)
- SwiftData persistence → no capability needed

## Auto-Configured Capabilities
| Capability | Status | Method |
|------------|--------|--------|
| Camera usage description | ✅ Configured | INFOPLIST_KEY_NSCameraUsageDescription in project.yml |
| Background Modes (processing) | ✅ Configured | INFOPLIST_KEY_UIBackgroundModes in project.yml |
| In-App Purchase | ✅ Configured | StoreKit 2 (no entitlement file needed; products configured in App Store Connect) |
| Local Notifications | ✅ Configured | No capability needed (UNUserNotificationCenter) |
| PrivacyInfo.xcprivacy | ✅ Configured | UserDefaults (CA92.1) + FileTimestamp (C617.1), no tracking |

## Manual Configuration Required
| Capability | Status | Steps |
|------------|--------|-------|
| CloudKit container | ⏳ Pending | App works with local SwiftData by default (graceful degradation). To enable sync: Xcode → Signing & Capabilities → + iCloud → Check CloudKit → create container `iCloud.com.zzoutuo.MintSnap` in Apple Developer portal |
| IAP products | ⏳ Pending | Create 3 products in App Store Connect (see price.md): com.mintsnap.pro.monthly, com.mintsnap.pro.yearly, com.mintsnap.boost.cloud100 |
| PriceCharting commercial token | ⏳ Pending | Email PriceCharting for commercial API license; token stays on Cloudflare Worker proxy only |

## No Configuration Needed
- Push Notifications entitlement (MVP uses local notifications only)
- HealthKit / Location / Siri / Watch (not in guide)

## Verification
- Build succeeded after configuration: ✅ (BUILD SUCCEEDED, generic/platform=iOS Simulator)
- All entitlements correct: ✅ (no entitlements file needed for MVP feature set)
- Signing verification (generic/platform=iOS): ✅ PASSED — "Apple Development: he zhou (VX3Q75X27B)", all targets signed
- DEVELOPMENT_TEAM: JP4TN5PTS3 baked at project level
- PrivacyInfo.xcprivacy: App target covered
