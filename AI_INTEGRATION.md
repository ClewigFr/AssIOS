# Integrating Anonymous Simple Stats with an AI assistant

Instructions for an AI coding assistant (Claude Code, Copilot, Cursor…) adding screen tracking to an iOS app (SwiftUI or UIKit) with this Swift package. The work has two phases, with a manual step in the dashboard in between:

1. **Phase 1:** the assistant lists the app's screens and writes `ass-pages.csv`.
2. **Manual step:** a person imports that file in the dashboard (**Importer un CSV**), then downloads the result (**Exporter en CSV**). The dashboard creates the UUIDs.
3. **Phase 2:** the assistant adds the package to the app, using the exported CSV.

What to ask the assistant:

> Phase 1: "Read AI_INTEGRATION.md from the Anonymous Simple Stats library, then list this app's screens in ass-pages.csv."
>
> Phase 2: "Here is the CSV exported from the dashboard: `<path>`. Follow phase 2 of AI_INTEGRATION.md to add the tracking. Backend endpoint: `https://ass-api.clewig.fr`."

---

## Rules for the assistant

These apply to both phases.

- **Anonymity is the product.** Never send or add anything that identifies a user or a device: no user ID, email, advertising ID (IDFA), `identifierForVendor`, IP address or install ID. A page name describes a screen ("Panier"), never a person or their data ("Panier de Jean", "Commande 1234").
- **Don't invent UUIDs.** Page and application UUIDs are created by the dashboard and come only from the exported CSV. If a screen has no line in the CSV, don't track it: list it in your summary and tell the person to add it in the dashboard.
- **One page per screen the user sees,** not per technical component. A dialog, bottom sheet or tab counts only if it's a real destination for the user. Don't log the same screen twice: for example in both a container view controller and the child it shows, or in both a SwiftUI view and the `UIHostingController` that hosts it.
- **The library never throws into the host app.** Its calls don't throw: don't wrap them in anything, and don't add retry logic: it batches, retries and keeps unsent views on its own.

---

## Phase 1: list the screens and write `ass-pages.csv`

### Find the screens

Look for every screen a user can reach:

| UI toolkit | Where the screens are |
|---|---|
| UIKit | classes extending `UIViewController`, `UITableViewController`, `UICollectionViewController`; scenes in storyboards (`*.storyboard`) and `*.xib` files |
| SwiftUI | `struct …: View` types used as destinations: `NavigationStack` / `NavigationLink` / `.navigationDestination(for:)`, `.sheet`, `.fullScreenCover`, and top-level `…Screen` / `…View` types shown as a whole screen |
| Tabs, page views | each tab of a `TabView` or `UITabBarController` that shows a separate screen |

Skip:
- screens that aren't shown to users: launch screens, routing or container controllers that show nothing themselves (`UINavigationController`, `UITabBarController`, `UISplitViewController`), debug and developer menus;
- system screens and other libraries' screens: permission alerts, Sign in with Apple, Apple Pay sheets, `SFSafariViewController`, share sheets.

### Name the pages

- Use a short name, as the app's team would say it, in the app's language, for example `Accueil`, `Panier`, `Paiement – Adresse`. These names are what people will read in the stats.
- Keep names unique within the app, and at most 255 characters each.
- The dashboard allows **30 pages per application** by default, and an import that would go over is refused. If the app has more screens, group the minor ones (settings sub-screens, steps of a flow) or keep the ones the team cares about, and say which ones you left out.
- An account has **5 applications** at most, and **100,000 views per month** across them. Going over the views only shows an alert in the dashboard, but that's another reason for one page per screen, never per item or per event.
- If the app also exists on Android, the same application and the same pages can be used for both: reuse the Android names so a screen is counted once whatever the platform. Or create a separate application to compare platforms.
- **One screen used in several modes** (for example, editing and creating a product): use one page, unless the team needs the modes counted separately.
- **One screen showing many different items** (for example, a product page): always one page. Never one page per product or per ID.

### Write the file

Create `ass-pages.csv` at the project root, UTF-8. It has a `name` header, then one page name per line. An optional second column says where the screen is in the code. The dashboard ignores that column, but it helps the person review the list.

```csv
name,source
Accueil,App/Home/HomeView.swift
Recherche,App/Search/SearchViewController.swift
Fiche produit,App/Product/ProductView.swift
Panier,App/Cart/CartView.swift
Paiement – Adresse,App/Checkout/AddressView.swift
Profil,App/Profile/ProfileView.swift
```

Quote a name that contains a comma, for example `"Paiement, étape 1"`.

### Finish phase 1

Don't change any app code in this phase. Tell the person:
1. how many screens you found, and the ones you deliberately skipped, and why;
2. what to do next: in the dashboard, open the application (create it if needed), click **Importer un CSV** and choose `ass-pages.csv`, then click **Exporter en CSV** and give you the downloaded file.

Importing the same file again later only creates the new names, so the list can be updated at any time.

---

## Phase 2: add the package with the exported CSV

### The input

The exported CSV has three columns, one line per page:

```csv
name,id,app_id
Accueil,30269ec7-8441-4493-ad65-8b3a7976c8c4,7f97b570-2cc1-4459-8dad-c86ddc4e809f
Panier,cf9dad24-712e-4c68-9825-06c61fe49345,7f97b570-2cc1-4459-8dad-c86ddc4e809f
```

- `name`: the page name;
- `id`: the page UUID, to pass to `logScreen` or `trackScreen`;
- `app_id`: the application UUID (the same on every line), to pass to `AssConfig(appId:)`.

Match each line to its screen by name. If phase 1's `ass-pages.csv` is still there, use its `source` column. Then delete `ass-pages.csv`: the exported file replaces it.

### 1. Add the dependency

The package is `https://github.com/ClewigFr/AssIOS`, product `AnonymousSimpleStats`, from version `0.5.0` (use the latest tag from https://github.com/ClewigFr/AssIOS/tags). It needs iOS 15 or later and has no dependency.

- **Xcode project:** an assistant can't reliably edit `project.pbxproj` to add a package. Ask the person to do it: **File → Add Package Dependencies…**, URL `https://github.com/ClewigFr/AssIOS`, rule "Up to Next Major Version" from `0.5.0`, then add `AnonymousSimpleStats` to the app target. Write the code below meanwhile.
- **Package.swift** (an app built from a package, or a feature module): add
  ```swift
  .package(url: "https://github.com/ClewigFr/AssIOS", from: "0.5.0")
  ```
  to `dependencies`, and `.product(name: "AnonymousSimpleStats", package: "AssIOS")` to the target's dependencies.
- **Tuist or XcodeGen:** add the same package and product in `Project.swift` / `project.yml`.
- If the project still uses the **CocoaPods** pod `AnonymousSimpleStats` (0.2.0 or earlier), remove it from the `Podfile` and run `pod install`: it is no longer published.

### 2. Put the ids in one Swift file

Generate a single enum from the CSV, for example `Analytics/AssPages.swift`. Name each constant after the page name, in `lowerCamelCase`, ASCII only. Keep the page name in a comment.

```swift
import AnonymousSimpleStats

/// Anonymous Simple Stats ids, generated from the dashboard's CSV export. Don't edit by hand: re-export and regenerate.
enum AssPages {
    static let appId = "7f97b570-2cc1-4459-8dad-c86ddc4e809f"

    /// Accueil
    static let accueil = "30269ec7-8441-4493-ad65-8b3a7976c8c4"
    /// Panier
    static let panier = "cf9dad24-712e-4c68-9825-06c61fe49345"
}

/// The stats manager, created on first use.
let ass = AnonymousSimpleStatsManager.getInstance(
    AssConfig(endpoint: "https://ass-api.clewig.fr", appId: AssPages.appId, verbose: isDebugBuild)
)

#if DEBUG
private let isDebugBuild = true
#else
private let isDebugBuild = false
#endif
```

Copy each UUID exactly as it appears in the CSV.

If the app has configurations or schemes with different backends, read the endpoint from the build settings (through `Info.plist`) instead of a literal.

### 3. Initialize once, at launch

Touch `ass` when the app starts, so views saved during a previous launch are sent and the app going to the background is observed from the start:

**SwiftUI**
```swift
@main
struct MyApp: App {
    init() {
        _ = ass
    }
    …
}
```

**UIKit**
```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    _ = ass
    …
}
```

`getInstance` returns the same instance afterwards: the config is only read the first time.

### 4. Log each screen when it's shown

Log each time the screen becomes visible, including when the user comes back to it. Use the hook that matches the toolkit:

**SwiftUI**

Add `trackScreen` once, on the screen's root view:
```swift
struct CartView: View {
    var body: some View {
        List { … }
            .navigationTitle("Panier")
            .trackScreen(ass, AssPages.panier)
    }
}
```
It logs when the view appears (also when it appears again, back from a pushed screen or a dismissed sheet), and each time the app comes back from the background with it shown. Don't use `onAppear { ass.logScreen(…) }`: it misses the return to the foreground.

Put it on the destination itself, not on the `NavigationStack` or the `TabView` that contains it. In a `TabView`, put it on each tab's content: only the selected tab appears.

**UIKit**
```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    ass.logScreen(AssPages.panier)
}
```
Use `viewDidAppear`, not `viewDidLoad`: `viewDidLoad` doesn't run again when the user comes back. Don't add it to container controllers (`UINavigationController`, `UITabBarController`, a custom container), only to the controllers that show the screen's content. A SwiftUI view hosted in a `UIHostingController` uses `trackScreen`, not `viewDidAppear` in the host.

Don't call `logScreen` in loops, in `body`, on scroll, or for events that aren't screens (button taps, errors). The library counts screen views only.

### 5. Check it

1. Build and run a debug build in the simulator: `verbose` is on.
2. Open a few screens, then filter the Xcode console (or Console.app) on the subsystem `fr.clewig.AnonymousSimpleStats`:
   - `log screen <uuid>` should appear once for each screen opened;
   - after 20 views, or when the app goes to the background (Home), the batch is sent and `OK` appears.
3. Warnings mean something is wrong:
   - `Ignored page view: "…" is not a UUID`: a constant was mistyped.
   - `Invalid appId …`: `appId` is wrong, and the library disables itself.
   - `Page views rejected by the server (400)` or `Some page views were rejected`: the ids don't belong to this application in the dashboard. Re-export the CSV and regenerate `AssPages`.
   - `Upload failed (…)` with an App Transport Security error: the endpoint is `http://`. Use `https://`.
4. The views appear in the dashboard, in the application's stats, within a few seconds of being sent.

### Finish phase 2

Tell the person:
- which screens are tracked, and where `trackScreen` or `logScreen` was added;
- the screens found in the code that have no line in the CSV, which are therefore not tracked;
- the CSV lines that match no screen. These are perhaps screens removed from the app: delete them in the dashboard if they're no longer used;
- if the package isn't added to the Xcode project yet, how to add it (step 1);
- to declare "Product Interaction, used for Analytics, not linked to the user, not used for tracking" in the App Store privacy details. The package's privacy manifest says the same.

---

## Updating later

When screens are added:
1. **Phase 1 again.** Add the new names to a CSV, or re-list the screens. Import the file: existing names are skipped, new ones are created.
2. **Export again**, regenerate `AssPages.swift` from the new export, and add `trackScreen` / `logScreen` calls for the new screens only.

A page's UUID never changes, so the existing calls keep working.
