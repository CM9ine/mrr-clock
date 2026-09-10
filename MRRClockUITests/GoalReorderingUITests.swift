import XCTest

@MainActor
final class GoalReorderingUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MRRClockUITests-" + UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let storeDirectory {
            try? FileManager.default.removeItem(at: storeDirectory)
        }
    }

    func test01DraggingTheLastGoalToTheFirstPositionUpdatesTheVisibleOrder() throws {
        launch()
        openGoals()

        dragGammaBeforeAlpha()

        XCTAssertEqual(visibleGoalNames(), ["Gamma", "Alpha", "Beta"])
    }

    func test02DraggingPersistsContiguousSortIndices() throws {
        launch()
        openGoals()
        dragGammaBeforeAlpha()

        let data = try Data(contentsOf: storeDirectory.appendingPathComponent("goals.json"))
        let file = try JSONDecoder().decode(PersistedGoalFile.self, from: data)
        let goals = file.goals.sorted { $0.sortIndex < $1.sortIndex }

        XCTAssertEqual(goals.map(\.name), ["Gamma", "Alpha", "Beta"])
        XCTAssertEqual(goals.map(\.sortIndex), [0, 1, 2])
    }

    func test03DraggedOrderSurvivesRelaunch() throws {
        launch()
        openGoals()
        dragGammaBeforeAlpha()

        app.terminate()
        launch()
        openGoals()

        XCTAssertEqual(visibleGoalNames(), ["Gamma", "Alpha", "Beta"])
    }

    func test04PinIdentitySurvivesAReorder() throws {
        launch()
        openGoals()
        dragGammaBeforeAlpha()

        let alphaPin = app.buttons["mrrclock.goal-pin.21000000-0000-0000-0000-000000000001"]
        XCTAssertEqual(alphaPin.value as? String, "pinned")
    }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-test-state", "reordering",
            "--ui-test-goal-store", storeDirectory.path,
        ]
        app.launch()
    }

    private func openGoals() {
        let statusItem = app.menuBars.statusItems["mrrclock.menu-bar-item"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let button = app.buttons["mrrclock.goals-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.click()
        XCTAssertTrue(app.windows["Goals"].waitForExistence(timeout: 5))
    }

    private func row(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)["mrrclock.goal-row.\(id)"]
    }

    private func dragGammaBeforeAlpha() {
        let alpha = row("21000000-0000-0000-0000-000000000001")
        let gamma = row("21000000-0000-0000-0000-000000000003")
        XCTAssertTrue(alpha.waitForExistence(timeout: 5))
        XCTAssertTrue(gamma.waitForExistence(timeout: 5))
        gamma.press(forDuration: 0.5, thenDragTo: alpha)
    }

    private func visibleGoalNames() -> [String] {
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'mrrclock.goal-row.'"))
            .allElementsBoundByAccessibilityElement
            .sorted { $0.frame.minY < $1.frame.minY }
        return rows.map(\.label)
    }
}

private struct PersistedGoalFile: Decodable {
    let goals: [PersistedGoal]
}

private struct PersistedGoal: Decodable {
    let name: String
    let sortIndex: Int
}
