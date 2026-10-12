import XCTest
@testable import Launchpad

@MainActor
final class AppScannerTests: XCTestCase {
    func testCancelledScanDoesNotCachePartialResults() async {
        let visible = makeApp(id: "00000000-0000-0000-0000-000000000001", name: "Visible")
        let gate = ScanGate(visible: [visible], hidden: [])
        let scanner = AppScanner(
            scanOverride: { showHidden, _ in
                await gate.scan(showHidden: showHidden)
            },
            startObservers: false
        )

        await gate.pauseNextScan()
        let cancelledScan = Task {
            await scanner.scanApps(showHidden: false, forceRefresh: true)
        }
        await gate.waitUntilPaused()
        cancelledScan.cancel()
        await gate.releaseScan()

        let cancelledResult = await cancelledScan.value
        XCTAssertTrue(cancelledResult.isEmpty)
        let freshResult = await scanner.scanApps(showHidden: false)
        XCTAssertEqual(freshResult.map(\.id), [visible.id])
        let scanModes = await gate.scanModes
        XCTAssertEqual(scanModes, [false, false], "A cancelled partial result must not be reused from cache")
    }

    func testEmptyScanResultsAreCached() async {
        let counter = ScanCounter()
        let scanner = AppScanner(
            scanOverride: { _, _ in
                await counter.recordScan()
                return []
            },
            startObservers: false
        )

        let firstResult = await scanner.scanApps()
        let secondResult = await scanner.scanApps()
        XCTAssertTrue(firstResult.isEmpty)
        XCTAssertTrue(secondResult.isEmpty)
        let scanCount = await counter.count
        XCTAssertEqual(scanCount, 1, "An empty scan should still be cached for the normal cache lifetime")
    }

    func testConcurrentCallerDoesNotReuseCachedResultsFromDifferentVisibilityMode() async {
        let visible = makeApp(id: "00000000-0000-0000-0000-000000000001", name: "Visible")
        let hidden = makeApp(id: "00000000-0000-0000-0000-000000000002", name: "Hidden")
        let gate = ScanGate(visible: [visible], hidden: [hidden])
        let scanner = AppScanner(
            scanOverride: { showHidden, _ in
                await gate.scan(showHidden: showHidden)
            },
            startObservers: false
        )

        let initial = await scanner.scanApps(showHidden: false, forceRefresh: true)
        XCTAssertEqual(initial.map(\.id), [visible.id])

        await gate.pauseNextScan()
        let forcedScan = Task {
            await scanner.scanApps(showHidden: true, forceRefresh: true)
        }
        await gate.waitUntilPaused()

        let waiterFinished = ScanCompletion()
        let waitingScan = Task {
            await waiterFinished.markStarted()
            let result = await scanner.scanApps(showHidden: true)
            await waiterFinished.markFinished()
            return result
        }
        await waiterFinished.waitUntilStarted()

        try? await Task.sleep(for: .milliseconds(50))
        let finishedBeforeRelease = await waiterFinished.isFinished
        XCTAssertFalse(finishedBeforeRelease, "A caller must wait rather than receive the old visibility mode's cache")

        await gate.releaseScan()
        let refreshed = await forcedScan.value
        let waited = await waitingScan.value
        let expectedIDs: Set<UUID> = [visible.id, hidden.id]
        XCTAssertEqual(Set(refreshed.map(\.id)), expectedIDs)
        XCTAssertEqual(Set(waited.map(\.id)), expectedIDs)
        let scanModes = await gate.scanModes
        XCTAssertEqual(scanModes, [false, true], "Compatible waiters should share the completed scan")
    }

    private func makeApp(id: String, name: String) -> AppItem {
        AppItem(
            id: UUID(uuidString: id)!,
            name: name,
            bundleIdentifier: "com.test.\(name.lowercased())",
            path: URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }
}

private actor ScanCounter {
    private(set) var count = 0

    func recordScan() {
        count += 1
    }
}

private actor ScanCompletion {
    private(set) var isFinished = false
    private var isStarted = false
    private var startedContinuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        isStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
    }

    func waitUntilStarted() async {
        if isStarted { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func markFinished() {
        isFinished = true
    }
}

private actor ScanGate {
    private let visible: [AppItem]
    private let hidden: [AppItem]
    private var shouldPauseNextScan = false
    private var isPaused = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private(set) var scanModes: [Bool] = []

    init(visible: [AppItem], hidden: [AppItem]) {
        self.visible = visible
        self.hidden = hidden
    }

    func pauseNextScan() {
        shouldPauseNextScan = true
    }

    func waitUntilPaused() async {
        if isPaused { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func releaseScan() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func scan(showHidden: Bool) async -> [AppItem] {
        scanModes.append(showHidden)
        if shouldPauseNextScan {
            shouldPauseNextScan = false
            isPaused = true
            startedContinuation?.resume()
            startedContinuation = nil
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
            isPaused = false
        }
        return showHidden ? visible + hidden : visible
    }
}
