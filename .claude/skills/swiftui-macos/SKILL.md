---
name: swiftui-macos
description: SwiftUI macOS project structure, MVVM architecture with @Observable, Scene configuration, SwiftData, URLSession async patterns, Xcode conventions, and AppKit interop guidance. Use when building, reviewing, or making tech stack decisions for a macOS app.
---

# SwiftUI macOS Best Practices

## Stack at a glance

| Tool | Job | When you feel it |
|---|---|---|
| SwiftUI | Declarative UI layer | Every `.swift` view file |
| Swift Concurrency (`async/await`, `actor`) | Safe concurrent code | Network calls, background tasks |
| `@Observable` (Observation framework) | ViewModel state | Reactive UI updates |
| SwiftData | Persistence | On-disk model storage |
| URLSession | Networking | All HTTP calls |
| XCTest / Swift Testing | Unit + UI tests | Business logic and critical flows |
| Xcode | Build, sign, archive | Project configuration and distribution |
| AppKit | Platform interop only | Controls SwiftUI cannot express |

**How they connect:**

```
SwiftUI Views observe @Observable ViewModels
         │
         ▼
   ViewModels call async service functions
         │
         ├── URLSession → remote API
         └── SwiftData ModelContext → local persistence
         │
         ▼
   App lifecycle managed by SwiftUI Scene
         │
         ├── WindowGroup (main UI)
         ├── Settings (preferences)
         └── MenuBarExtra (optional tray)
```

---

## Project structure

Organize by feature/domain:

```
MyApp/
├── App/
│   ├── MyApp.swift             # @main entry point, Scene configuration
│   └── AppDelegate.swift       # Only if NSApplicationDelegate hooks needed
├── Features/
│   ├── Orders/
│   │   ├── OrdersView.swift
│   │   ├── OrdersViewModel.swift
│   │   └── OrdersService.swift
│   └── Settings/
│       └── SettingsView.swift
├── Shared/
│   ├── Components/             # Reusable views
│   ├── Models/                 # SwiftData @Model types
│   └── Services/               # URLSession wrappers, shared helpers
└── Resources/
    └── Assets.xcassets
```

Tests mirror this structure under `MyAppTests/` and `MyAppUITests/`.

---

## App entry point and Scene configuration

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
```

Use `MenuBarExtra` for menu-bar-resident apps:

```swift
MenuBarExtra("My App", systemImage: "circle.fill") {
    MenuBarView()
}
.menuBarExtraStyle(.window)
```

---

## ViewModel pattern with @Observable

Use the `Observation` framework (`@Observable` macro, iOS 17 / macOS 14+). Do not use `ObservableObject` / `@Published` for new code.

```swift
@Observable
final class OrdersViewModel {
    var orders: [Order] = []
    var isLoading = false
    var errorMessage: String?

    private let service: OrdersService

    init(service: OrdersService = .shared) {
        self.service = service
    }

    func loadOrders() async {
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await service.fetchOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

```swift
struct OrdersView: View {
    @State private var viewModel = OrdersViewModel()

    var body: some View {
        List(viewModel.orders) { order in
            OrderRow(order: order)
        }
        .task { await viewModel.loadOrders() }
        .overlay { if viewModel.isLoading { ProgressView() } }
    }
}
```

Rules:
- ViewModels are `@Observable final class` -- never `struct`
- Views hold the ViewModel as `@State` at the root of the feature
- Inject dependencies through `init`; use `@Environment` for app-wide services
- No `@StateObject` / `@ObservedObject` in new code

---

## Swift Concurrency

```swift
// Structured concurrency for parallel work
func loadDashboard() async throws -> Dashboard {
    async let orders = ordersService.fetchOrders()
    async let profile = profileService.fetchProfile()
    return Dashboard(orders: try await orders, profile: try await profile)
}

// Actor for shared mutable state
actor SessionStore {
    private var token: String?

    func setToken(_ token: String) { self.token = token }
    func getToken() -> String? { token }
}
```

Rules:
- No `DispatchQueue` in new code; use `async/await` and structured concurrency
- Background work: `Task { }` from the call site; `Task.detached` only when explicitly needed
- Main-actor safety: `@MainActor` on ViewModel methods that update UI; SwiftUI views are `@MainActor` by default
- Never use `NotificationCenter` for data flow between owned objects; use `@Observable` or `async` streams

---

## Networking (URLSession)

```swift
struct OrdersService {
    static let shared = OrdersService()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetchOrders() async throws -> [Order] {
        let url = URL(string: "https://api.example.com/v1/orders")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.badStatus
        }
        return try decoder.decode([Order].self, from: data)
    }
}
```

Rules:
- All HTTP calls through `URLSession` with `async/await`
- Inject `URLSession` for testability
- Use `Codable` + `JSONDecoder` for all JSON parsing
- Never store tokens in `UserDefaults`; use the Keychain

---

## Persistence (SwiftData)

```swift
@Model
final class Order {
    var id: UUID
    var title: String
    var status: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, status: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
    }
}
```

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Order.self)
    }
}
```

```swift
struct OrdersView: View {
    @Query(sort: \Order.createdAt, order: .reverse) var orders: [Order]
    @Environment(\.modelContext) private var context

    func addOrder() {
        let order = Order(title: "New", status: "pending")
        context.insert(order)
    }
}
```

Rules:
- Use SwiftData for new persistence; Core Data only when migrating existing data
- Never bypass `ModelContext` to write directly
- Schema migrations via `VersionedSchema` and `SchemaMigrationPlan`

---

## Secrets and credentials

- Store all tokens, passwords, and API keys in the **Keychain** (`Security.framework`)
- Never use `UserDefaults`, plist, or hardcoded strings for credentials
- Use `KeychainHelper` wrapper pattern; inject it like any other service for testability

---

## Xcode project conventions

- One target per platform (macOS target separate from iOS if sharing code)
- Signing: Automatic signing in development; manual for distribution
- Entitlements: add only what the app uses; review before submission
- Info.plist: no hardcoded bundle IDs; use Xcode build settings (`$(PRODUCT_BUNDLE_IDENTIFIER)`)
- Schemes: one per environment (Debug, Release); no dead schemes
- SwiftLint: enforce via a Build Phase run script; treat warnings as errors in CI
- No `#if DEBUG` around logic that affects production behavior; use dependency injection instead

---

## Multiplatform conditional code

When sharing code between macOS and iOS in a single target:

```swift
#if os(macOS)
    // macOS-specific implementation
#else
    // iOS fallback
#endif
```

Keep `#if os()` blocks as small as possible. Prefer protocol-based abstraction over broad conditional compilation.

---

## Code style

| Convention | Value |
|---|---|
| Language | Swift 5.10+ |
| Style enforcement | SwiftLint (`.swiftlint.yml` at project root) |
| CI gate | SwiftLint with zero warnings |
| Access control | `private` by default; `internal` only when needed across files; `public` only for library targets |
| Force unwrap | Never, except at documented crash-on-nil contract boundaries |
| Implicit return | Use in single-expression closures and computed properties |
| Type inference | Prefer where unambiguous; explicit where it aids readability |
