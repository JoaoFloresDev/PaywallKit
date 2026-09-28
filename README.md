# PaywallKit

Shared GambitStudio paywall + StoreKit 2 manager. Self-contained GambitStudio standard.

## What's inside

- **`StoreKitManager`** (singleton, `@MainActor ObservableObject`) — load products, purchase, restore, listen for transaction updates, expose `isPremium`.
- **`PaywallScaffold`** — drop-in SwiftUI view with hero gradient + features list + plan cards + CTA + restore + premium-active state.
- **`PurchaseScaffold`** — high-converting alternative (trial detection, SAVE %, cooldown close). See below.
- **`PostPurchaseView`** — tela pós-compra ("o que você desbloqueou" + 1 próximo passo + opt-in dos lembretes de trial). See below.
- **`TrialTimelineView`** — "como funciona seu trial" (Hoje / Dia 5 / Dia 7), renderizado pelo `PurchaseScaffold` enquanto o plano selecionado tem trial. See below.
- **`TrialReminderScheduler`** — 3 notificações locais do trial (+6 h, T-2 dias, último dia), só depois do opt-in; canceladas quando o trial converte. See below.
- **`ExitOfferSheet`** — oferta de saída (intro offer REAL da ASC) uma vez por usuário, prazo de 24 h persistido. See below.
- **`PurchaseSocialProof`** — slot de prova social (nota real + 1 citação) do `PurchaseScaffold`.
- **`PaywallAnalytics`** — hook único de eventos (`PaywallAnalytics.Event.*` lista os nomes).
- **`PaywallCTAFill`** — gradiente padrão do CTA primário (mesma receita do `OnboardingCTAFill`).

## Trial e planos — recomendação (pesquisa 2026-09, achado 6)

**Anual com trial de 7 dias + semanal sem trial.** Dados RevenueCat (17k+ apps, ago/2025-jul/2026): trial de 5-9 dias converte 45,9% vs 39,6% em ≤4 dias; trial de 3 dias é cancelado no dia 0 em 55,4% dos casos (84% até o D1). Semanal+trial tem o maior LTV 12m na Adapty, mas retém 4x pior que anual — o anual (com trial) é o plano-âncora, o semanal é a porta de entrada barata.

- O trial é configurado na ASC (intro offer `FREE_TRIAL`, duração `ONE_WEEK`, 1 POST por território — LEARNINGS #1/#48), não no código. O kit só DETECTA: `product.subscription.introductoryOffer.paymentMode == .freeTrial`.
- `PurchaseScaffold` mostra o trial no card e troca o CTA pra `startTrialText`. A duração é normalizada junto com a unidade (`PurchasePeriod.normalisedCount`): um trial de 7 dias que o StoreKit reporte como `.day × 7` lê "1-Week Trial" (LEARNINGS #49 — o simulador entrega `P1W` como dia × 7).
- Health/Fitness: anual como default; Productivity: mensal (achado 7). `StoreKitManager.configure(weekly:yearly:)` continua o modelo padrão.

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
        privacyURL: URL(string: "https://drive.google.com/file/d/147xkp4cekrxhrBYZnzV-J4PzCSqkix7t/view"),
        backgroundColor: AppColors.background,                       // opcional: o kit pinta a superfície
        palette: PurchasePalette(text: AppColors.textPrimary,        // opcional: cores da paleta do app
                                 supportingText: AppColors.textSecondary,
                                 footerText: AppColors.textSecondary,
                                 cardFill: AppColors.surface),
        cornerRadius: AppSpacing.cornerRadius                        // opcional: raio dos cards/CTA (default 6)
    )
}
```

Layout (28/09/2026): a coluna preenche a tela — hero (16% do canvas, 80-140pt), título, benefícios, e os cards de plano logo acima do CTA; a folga se distribui entre as faixas (nada de uma tira vazia), e em canvas curto (SE, iPad compat) a coluna rola. `backgroundColor:` e `palette:` (`PurchasePalette`: `text` / `supportingText` / `footerText` / `cardBorder` / `cardFill` / `onAccent` / `badgeFill`) e `cornerRadius:` (cards de plano + CTA, default 6) são opcionais — sem eles o kit deriva as cores do foreground atual e mantém o raio histórico. `previewPlans: [PurchasePlanPreview]` renderiza cards só-visuais enquanto a StoreKit não devolve produto (prints/QA no simulador sem `.storekit`) — nunca vendem nada.

A % de SAVE é calculada do preço semanal anualizado (×52) vs o anual; trial é detectado via `product.subscription.introductoryOffer`. Os textos de CTA/restore/terms são parâmetros (default em inglês) — passe `String(localized:)` pra localizar. Use `PaywallScaffold` quando quiser o layout mais sóbrio com gradiente; `PurchaseScaffold` quando quiser a versão mais agressiva de conversão.

---

## Pós-compra: `PostPurchaseView`

Tela mostrada logo depois de uma compra bem-sucedida: título, 2-3 linhas de "o que você desbloqueou" (`PaywallFeatureItem`, strings do app) e UM próximo passo (CTA primário). Confirmação + ação concreta reduz cancelamento no dia 0 (pesquisa 2026-09, achados 6 e 9). Botão secundário opcional pra pedir permissão de notificação — entra em loading no tap e some depois da resposta (RULES: loading em request de sistema). Asset-free (hero = SF Symbol). O kit NÃO apresenta sozinho: o host observa `StoreKitManager.shared.isPremium` (ou o retorno de `purchase(_:)`) e apresenta.

```swift
@ObservedObject private var store = StoreKitManager.shared
@State private var showPostPurchase = false

.onChange(of: store.isPremium) { _, isPremium in if isPremium { showPostPurchase = true } }
.fullScreenCover(isPresented: $showPostPurchase) {
    PostPurchaseView(
        gradient: [AppColors.primary, AppColors.primary.opacity(0.85)],
        title: String(localized: "postPurchase.title"),
        subtitle: String(localized: "postPurchase.subtitle"),
        unlocked: [
            .init(symbol: "infinity", title: String(localized: "postPurchase.unlocked1")),
            .init(symbol: "sparkles", title: String(localized: "postPurchase.unlocked2")),
            .init(symbol: "icloud.fill", title: String(localized: "postPurchase.unlocked3"))
        ],
        primaryButtonText: String(localized: "postPurchase.cta"),
        onPrimary: { showPostPurchase = false; openFirstProFeature() },
        notificationsButtonText: String(localized: "postPurchase.notifications"),
        onEnableNotifications: { await NotificationService.shared.requestAuthorization() }
    )
}
```

Accessibility ids: `paywall.postPurchase.primary`, `paywall.postPurchase.notifications`. Parâmetros opcionais: `heroSymbol` (default `checkmark.seal.fill`), `accent` (cor do texto do CTA; default = primeira cor do gradiente).

## Analytics (`PaywallAnalytics`)

Conectar uma vez no `@main`: `PaywallAnalytics.onEvent = { Analytics.log($0, $1) }` e setar `PaywallAnalytics.source` antes de apresentar. Os nomes estão em `PaywallAnalytics.Event`:

| Constante | Evento | Canônico (taxonomia §2.4) |
|---|---|---|
| `paywallShown` / `paywallDismissed` | `paywall_shown` / `paywall_dismissed` | sim |
| `purchaseStarted` / `purchaseSuccess` / `purchaseAbandoned` / `purchaseRestored` | `purchase_*` | sim |
| `premiumGateHit` | `premium_gate_hit` | sim |
| `postPurchaseShown` | `post_purchase_shown` (params `placement`, `rows`, + `source`) | sim (desde 28/09/2026) — emitido pela `PostPurchaseView.onAppear` |
| `planSelected` | `plan_selected` (`product_id`, `period`, `trial`) | sim — tap num card do `PurchaseScaffold` (anual vs semanal ANTES do CTA) |
| `exitOfferShown` | `exit_offer_shown` (`reason` dismiss/abandon, `product_id`) | sim — `ExitOfferSheet.onAppear` |
| `trialReminderScheduled` | `trial_reminder_scheduled` (`days_before`, `kind`) | sim — um por lembrete agendado pelo `TrialReminderScheduler` |

`PaywallAnalytics.installDate` (opcional, setar no `@main` junto do `onEvent`, persistindo a data do 1º launch): quando definido, TODO evento carrega `days_since_install` (Int) — receita do dia 0 vs total (pesquisa 2026-09, métrica 7).

---

## Kits r2 (28/09/2026) — o que a pesquisa 2026-09 pediu, tudo aditivo

**Auditoria do toggle de trial (achado 7):** o `PurchaseScaffold` NUNCA teve o "free trial toggle" do código original (a Apple rejeita por 3.1.2 desde jan/2026) — o trial mora em UM plano (intro offer da ASC) e o usuário só escolhe o card. Anual (com trial) pré-selecionado porque os produtos vêm ordenados por preço; o semanal aparece como âncora com o preço por semana. Não adicionar switch de trial.

### `TrialTimelineView` — "como funciona seu trial"
Três marcos (Hoje: acesso total · Dia N-2: lembrete · Dia N: cobrança), dias calculados do intro offer do produto (`TrialTimeline.days(of:)`), preço pós-trial na linha da cobrança (exigência da Apple, achado 8). Só aparece enquanto o plano selecionado tem trial. Strings do app:

```swift
PurchaseScaffold(
    ...,
    trialTimeline: TrialTimelineStrings(
        todayLabel: String(localized: "paywall.trial.today"),            // "Hoje"
        dayLabel: { String(localized: "paywall.trial.dayN \($0)") },     // "Dia 5"
        accessTitle: String(localized: "paywall.trial.access"),          // "Acesso total a tudo"
        reminderTitle: String(localized: "paywall.trial.reminderRow"),   // "Avisamos antes de cobrar"
        chargeTitle: { String(localized: "paywall.trial.charge \($0)") }, // "Cobrança de R$ 99,90 por ano"
        cancelNote: String(localized: "paywall.trial.cancelNote")        // opcional
    )
)
```
Standalone: `TrialTimelineView(trialDays:price:strings:accentColor:palette:cornerRadius:)`. Id `paywall.trialTimeline` (+ `.today/.reminder/.charge`).

### `TrialReminderScheduler` + opt-in na `PostPurchaseView`
Cumpre a promessa do timeline (achado 6: opt-in de push 6% → 74% quando prometido no paywall). `enable(trialEnd:strings:)` pede a permissão (alert+sound) e agenda **+6 h** (nudge de valor), **T-2 dias 10:00** e **manhã do último dia 09:00** (pula o que já passou ou não cabe num trial curto). Ids `paywallkit.trialReminder.*`; `cancel()` remove só esses. O `StoreKitManager` expõe `trialEndDate` (do entitlement em trial, iOS 17.2+) e **cancela sozinho** quando chega uma transação que não é mais trial. Cada lembrete emite `trial_reminder_scheduled(days_before, kind)`.

```swift
PostPurchaseView(
    ...,
    remindersButtonText: String(localized: "postPurchase.reminders"),   // "Me avise antes de cobrar"
    onEnableReminders: {
        guard let end = StoreKitManager.shared.trialEndDate else { return }
        await TrialReminderScheduler.enable(trialEnd: end, strings: TrialReminderStrings(
            valueNudgeTitle: ..., valueNudgeBody: ...,
            beforeEndTitle: ..., beforeEndBody: { days in ... },
            lastDayTitle: ..., lastDayBody: ...
        ))
    }
)
```
O botão entra em loading no tap e some depois da resposta (mesma regra do `onEnableNotifications`; se os dois forem passados, o de lembretes vence). Id `paywall.postPurchase.reminders`. `TrialReminderScheduler.plan(trialEnd:now:calendar:)` é puro — testável sem UNUserNotificationCenter.

### `ExitOfferSheet` — oferta de saída, uma vez, com prazo real
Aparece **uma vez por instalação** depois de fechar o paywall (`reason: .dismiss`) ou cancelar a folha de compra (`reason: .abandon`), com um **produto separado** que tenha intro offer na ASC/`.storekit` (ex.: mensal com 1º mês com desconto) — o kit mostra `introductoryOffer.displayPrice` riscando o preço cheio; **nunca inventa desconto**. Prazo de 24 h persistido (`ExitOffer.deadline`), contagem real na tela, nunca reinicia (achado 8: urgência só se for verdade). Emite `exit_offer_shown`.

```swift
PurchaseScaffold(
    ...,
    exitOffer: ExitOfferConfiguration(
        productID: "app.pro.monthly",
        strings: ExitOfferStrings(
            title: String(localized: "exitOffer.title"),
            subtitle: String(localized: "exitOffer.subtitle"),
            priceLine: { offer, regular in String(localized: "exitOffer.priceLine \(offer) \(regular)") },
            deadlineLabel: { String(localized: "exitOffer.deadline \($0)") },
            ctaText: String(localized: "exitOffer.cta"),
            dismissText: String(localized: "exitOffer.dismiss"),
            unavailableText: String(localized: "exitOffer.unavailable")
        ),
        purchaseOptions: [],                      // promotional offer assinado, se houver
        preview: ExitOfferPreview(offerPrice: "R$ 3,49", regularPrice: "R$ 6,99")  // só QA/prints
    )
)
```
Standalone: `ExitOfferSheet(productID:strings:accentColor:...:reason:onFinished:)` num `.sheet` do app. Estado: `ExitOffer.hasBeenShown` / `isActive()` / `markShown()`; `ExitOffer.reset()` só em DEBUG. Ids `paywall.exitOffer`, `.cta`, `.dismiss`, `.deadline`. O mensal da oferta fica FORA de `StoreKitManager.configure(weekly:yearly:)` — o paywall principal continua com 2 planos (achado 12).

### `socialProof:` no `PurchaseScaffold`
`PurchaseSocialProof(rating:ratingCountText:quote:author:)` entre os benefícios e os cards. Passe a nota REAL da loja (o kit não valida) — "4,9 estrelas" inventado é anti-cue do visual review. Id `paywall.socialProof`.

