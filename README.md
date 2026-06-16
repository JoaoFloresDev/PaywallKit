# PaywallKit

Shared GambitStudio paywall + StoreKit 2 manager. Self-contained GambitStudio standard.

## What's inside

- **`StoreKitManager`** (singleton, `@MainActor ObservableObject`) — load products, purchase, restore, listen for transaction updates, expose `isPremium`.
- **`PaywallScaffold`** — drop-in SwiftUI view with hero gradient + features list + plan cards + CTA + restore + premium-active state.

## Install

```swift
.package(path: "/Users/joaoflores/Documents/GambitStudio/_GambitStudio/packages/PaywallKit")
```

Add `PaywallKit` as dependency to your target.

## Setup (once at app launch)

```swift
// In your App init or AppDelegate
import PaywallKit

@main
struct MyApp: App {
    init() {
        StoreKitManager.shared.configure(
            monthly: "myapp.pro.monthly",
            yearly: "myapp.pro.yearly"
        )
    }
    // ...
}
```

`configure(...)` loads products immediately and starts the transaction listener.

## Show the paywall

```swift
import PaywallKit
import SwiftUI

struct SettingsView: View {
    @State private var showingPaywall = false

    var body: some View {
        Button("Upgrade") { showingPaywall = true }
            .fullScreenCover(isPresented: $showingPaywall) {
                PaywallScaffold(
                    gradient: [AppColors.primary, AppColors.primary.opacity(0.9)],
                    title: String(localized: "premium.title"),
                    subtitle: String(localized: "premium.subtitle"),
                    features: [
                        .init(symbol: "lock.shield.fill", title: String(localized: "premium.feature.password.title")),
                        .init(symbol: "faceid", title: String(localized: "premium.feature.faceid.title")),
                        .init(symbol: "folder.badge.plus", title: String(localized: "premium.feature.unlimited.title")),
                        .init(symbol: "headphones", title: String(localized: "premium.feature.support.title"))
                    ],
                    monthlyLabel: .monthly(title: String(localized: "premium.plan.monthly"),
                                            period: String(localized: "premium.price.month")),
                    yearlyLabel: .yearly(title: String(localized: "premium.plan.annual"),
                                          period: String(localized: "premium.price.year"),
                                          recommendedBadge: String(localized: "premium.plan.recommended")),
                    ctaButtonText: String(localized: "premium.button.subscribe"),
                    restoreButtonText: String(localized: "premium.button.restore"),
                    eulaText: String(localized: "legal.eula"),
                    privacyText: String(localized: "legal.privacy"),
                    activeStateConfig: .init(
                        title: String(localized: "premium.active.title"),
                        description: String(localized: "premium.active.description"),
                        manageButtonText: String(localized: "premium.manage.subscription")
                    )
                )
            }
    }
}
```

## Check premium status anywhere

```swift
if StoreKitManager.shared.isPremium {
    // unlock feature
}
```

Or reactively in SwiftUI:

```swift
@ObservedObject private var store = StoreKitManager.shared

var body: some View {
    Text(store.isPremium ? "Active" : "Free")
}
```

## Required Localizable.xcstrings keys (3 locales: pt-BR, en-US, es-ES)

- `premium.title` / `.subtitle`
- `premium.feature.*` (one set per feature you list)
- `premium.plan.monthly` / `.annual` / `.recommended`
- `premium.price.month` / `.year`
- `premium.button.subscribe` / `.restore`
- `premium.active.title` / `.description`
- `premium.manage.subscription`

## StoreKit Configuration

Create `Configuration.storekit` in your Xcode project with the product IDs you passed to `configure(...)`. In the scheme's Run options, select that file. This lets you test purchases on simulator without Apple account.

Product ID convention: `[appname].pro.monthly` · `[appname].pro.yearly` · `[appname].pro.lifetime`

---

## Alternativa high-converting: `PurchaseScaffold`

Paywall estilo "Adam Lyttle": hero com shake, timer de cooldown no botão fechar, badge de SAVE %, detecção de trial e cards de plano selecionáveis. Ligado ao **mesmo `StoreKitManager.shared` nativo** (StoreKit 2, sem SDK terceiro). Hero é SF Symbol por padrão (zero assets), com `heroImageName` opcional.

Adaptado de [Paywall-PurchaseView-SwiftUI](https://github.com/adamlyttleapps/Paywall-PurchaseView-SwiftUI) (Adam Lyttle, MIT) — o `PurchaseModel` stub original foi trocado pelo `StoreKitManager`.

```swift
import PaywallKit

// configure uma vez no launch (igual ao PaywallScaffold):
StoreKitManager.shared.configure(
    weekly: "myapp.pro.weekly",
    yearly: "myapp.pro.yearly"
)

.fullScreenCover(isPresented: $showPaywall) {
    PurchaseScaffold(
        isPresented: $showPaywall,
        title: String(localized: "paywall.title"),
        accentColor: AppColors.primary,
        features: [
            .init(title: String(localized: "paywall.feature1"), icon: "infinity"),
            .init(title: String(localized: "paywall.feature2"), icon: "sparkles"),
            .init(title: String(localized: "paywall.feature3"), icon: "lock.open.fill"),
            .init(title: String(localized: "paywall.feature4"), icon: "lock.square.stack")
        ],
        heroSymbol: "crown.fill",
        termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        privacyURL: URL(string: "https://drive.google.com/file/d/147xkp4cekrxhrBYZnzV-J4PzCSqkix7t/view")
    )
}
```

A % de SAVE é calculada do preço semanal anualizado (×52) vs o anual; trial é detectado via `product.subscription.introductoryOffer`. Os textos de CTA/restore/terms são parâmetros (default em inglês) — passe `String(localized:)` pra localizar. Use `PaywallScaffold` quando quiser o layout mais sóbrio com gradiente; `PurchaseScaffold` quando quiser a versão mais agressiva de conversão.
