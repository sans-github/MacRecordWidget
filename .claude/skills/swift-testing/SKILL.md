---
name: swift-testing
description: Swift and macOS app testing conventions -- XCTest unit tests, Swift Testing framework, XCUITest E2E tests, async test patterns, ViewModel testing with @Observable, and snapshot testing. Use when writing, reviewing, or evaluating Swift app test code.
---

# Swift Testing

## Test types

| Type | Tool | Scope | When to use |
|---|---|---|---|
| Unit | Swift Testing (`@Test`) or XCTest | Single function, ViewModel, service | Business logic, data transformations, error handling |
| Integration | XCTest with real dependencies | Multiple layers without network | SwiftData queries, service composition |
| UI / E2E | XCUITest | Full app in simulator | Critical user journeys end-to-end |
| Snapshot | swift-snapshot-testing | View rendering | Regression detection on UI components |

---

## Swift Testing framework (preferred for unit tests)

Swift Testing (`import Testing`) is the modern replacement for XCTest unit tests. Use it for all new unit tests targeting Swift 5.9+ / macOS 14+.

```swift
import Testing
@testable import MyApp

@Suite("OrdersViewModel")
struct OrdersViewModelTests {

    @Test("loads orders successfully")
    func loadsOrdersOnAppear() async throws {
        let service = MockOrdersService(result: .success([.fixture()]))
        let vm = OrdersViewModel(service: service)

        await vm.loadOrders()

        #expect(vm.orders.count == 1)
        #expect(vm.isLoading == false)
    }

    @Test("sets error message on failure")
    func setsErrorOnFailure() async throws {
        let service = MockOrdersService(result: .failure(APIError.badStatus))
        let vm = OrdersViewModel(service: service)

        await vm.loadOrders()

        #expect(vm.errorMessage != nil)
    }
}
```

Rules:
- Use `#expect` not `XCTAssert*` in Swift Testing suites
- Use `@Suite` to group related tests
- Use `@Test("description")` for readable test names
- `async` tests work natively -- no `expectation` / `fulfill` boilerplate

---

## XCTest unit tests (legacy or mixed targets)

Use when the target does not support Swift Testing or when testing code that uses XCTestExpectation-based patterns.

```swift
import XCTest
@testable import MyApp

final class OrdersServiceTests: XCTestCase {

    func test_fetchOrders_returnsDecodedOrders() async throws {
        let session = URLSessionMock(data: ordersJSON, response: .ok)
        let service = OrdersService(session: session)

        let orders = try await service.fetchOrders()

        XCTAssertEqual(orders.count, 2)
    }

    func test_fetchOrders_throwsOnBadStatus() async throws {
        let session = URLSessionMock(data: Data(), response: .notFound)
        let service = OrdersService(session: session)

        await XCTAssertThrowsErrorAsync(try await service.fetchOrders())
    }
}
```

---

## Async test patterns

Swift Testing handles `async` natively. In XCTest:

```swift
func test_asyncOperation() async throws {
    // Just mark the test `async throws` -- no expectation needed
    let result = try await myAsyncFunction()
    XCTAssertEqual(result, expected)
}
```

For code using `Task` internally, prefer injecting a test clock or using `withCheckedContinuation` stubs. Do not use `sleep` in tests.

---

## ViewModel testing with @Observable

`@Observable` ViewModels are plain classes -- test them directly without any special test harness.

```swift
@Test("disables button while loading")
func buttonDisabledWhileLoading() async {
    let service = MockOrdersService(delay: 0.1)
    let vm = OrdersViewModel(service: service)

    let task = Task { await vm.loadOrders() }
    // isLoading should be true immediately after kick-off
    #expect(vm.isLoading == true)
    await task.value
    #expect(vm.isLoading == false)
}
```

Inject all dependencies through `init`. Never test against real network or disk in unit tests.

---

## Mocking strategy

Use protocol-based mocks. Define a protocol for every external dependency:

```swift
protocol OrdersServiceProtocol {
    func fetchOrders() async throws -> [Order]
}

struct MockOrdersService: OrdersServiceProtocol {
    let result: Result<[Order], Error>

    func fetchOrders() async throws -> [Order] {
        try result.get()
    }
}
```

Do not use third-party mock generation libraries unless the project has already adopted one.

---

## XCUITest (E2E)

```swift
import XCTest

final class OrdersUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    func test_userCanCancelPendingOrder() throws {
        let orderList = app.tables["orders-list"]
        XCTAssert(orderList.waitForExistence(timeout: 5))

        let cancelButton = orderList.buttons["Cancel order"].firstMatch
        XCTAssert(cancelButton.exists)
        cancelButton.click()

        let confirmation = app.sheets.firstMatch
        XCTAssert(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Confirm"].click()

        XCTAssert(app.staticTexts["Order cancelled"].waitForExistence(timeout: 3))
    }
}
```

Rules:
- Set `accessibilityIdentifier` on key containers; use `.accessibilityLabel` for interactive elements
- Use `launchArguments` to put the app in a known test state (clear keychain, mock server, etc.)
- E2E tests cover critical journeys only -- not every screen
- Use `waitForExistence(timeout:)` not `sleep`; flaky tests are bugs

---

## Snapshot testing

Use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) for regression detection on SwiftUI views.

```swift
import SnapshotTesting
import SwiftUI
import XCTest

final class OrderRowSnapshotTests: XCTestCase {

    func test_orderRow_pending() {
        let view = OrderRow(order: .fixture(status: "pending"))
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 72)))
    }

    func test_orderRow_darkMode() {
        let view = OrderRow(order: .fixture(status: "pending"))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 72)))
    }
}
```

Rules:
- Always include a dark mode snapshot for every component snapshot
- Record mode: run once with `record: true` to create reference images; never leave it enabled in CI
- Store snapshots in `__Snapshots__/` alongside the test file
- Snapshot tests run on a fixed simulator resolution to avoid CI drift

---

## Test fixtures

Define static fixtures on model types to avoid repetition:

```swift
extension Order {
    static func fixture(
        id: UUID = UUID(),
        title: String = "Test Order",
        status: String = "pending",
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> Order {
        Order(id: id, title: title, status: status, createdAt: createdAt)
    }
}
```

---

## Running tests

```bash
# All unit + integration tests (command line)
xcodebuild test -scheme MyApp -destination 'platform=macOS'

# UI tests only
xcodebuild test -scheme MyApp -destination 'platform=macOS' -only-testing MyAppUITests

# SwiftLint (runs before tests in CI)
swiftlint --strict
```

In Xcode: `⌘U` runs all tests; `⌃⌥⌘U` re-runs the last test.
