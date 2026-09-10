import XCTest

@MainActor
final class SetupWindowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test02PlusOpensAFocusedGoalEditor() throws {
        openGoalsFromNoGoals()

        let addGoal = app.buttons["mrrclock.add-goal"]
        XCTAssertTrue(addGoal.waitForExistence(timeout: 5))
        addGoal.click()

        let name = app.textFields["mrrclock.goal-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: focused, object: name)], timeout: 5), .completed)
        let save = app.buttons["mrrclock.goal-save"]
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled)
    }

    func test03GoalsButtonRaisesAnExistingGoalsWindow() throws {
        launch(state: "loaded")
        openMenuBarExtra()
        let goalsButton = app.buttons["mrrclock.goals-button"]
        XCTAssertTrue(goalsButton.waitForExistence(timeout: 5))
        goalsButton.click()
        let goals = app.windows["Goals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5))

        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        let reopenedGoalsButton = openMenuBarExtra(revealing: "mrrclock.goals-button")
        reopenedGoalsButton.click()

        XCTAssertEqual(app.windows.matching(identifier: "Goals").count, 1)
        XCTAssertTrue(goals.isHittable)
        XCTAssertEqual(app.windows.element(boundBy: 0).frame, goals.frame)
    }

    func test04SettingsButtonOpensAUsableSettingsWindow() throws {
        launch(state: "loaded")
        openMenuBarExtra()
        let settingsButton = app.buttons["mrrclock.settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let settings = app.windows["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(app.windows.element(boundBy: 0).frame, settings.frame)
        XCTAssertFalse(settingsButton.isHittable)
        XCTAssertTrue(app.datePickers["mrrclock.settings-earnings-start"].isHittable)
        XCTAssertTrue(app.switches["mrrclock.settings-include-trials"].isHittable)
    }

    func test05ReopeningSettingsRaisesOneWindow() throws {
        launch(state: "loaded")
        openMenuBarExtra()
        let settingsButton = app.buttons["mrrclock.settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()
        let settings = app.windows["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))

        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        let reopenedSettingsButton = openMenuBarExtra(revealing: "mrrclock.settings-button")
        reopenedSettingsButton.click()

        XCTAssertEqual(app.windows.matching(identifier: "Settings").count, 1)
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(app.windows.element(boundBy: 0).frame, settings.frame)
    }

    @MainActor
    func test01AddFirstGoalOpensAVisibleGoalsWindow() throws {
        launch(state: "no-goals")
        openMenuBarExtra()

        let addFirstGoal = app.buttons["mrrclock.add-first-goal"]
        XCTAssertTrue(addFirstGoal.waitForExistence(timeout: 5))
        addFirstGoal.click()

        let goals = app.windows["Goals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5))
        XCTAssertTrue(goals.isHittable)
        XCTAssertEqual(app.windows.element(boundBy: 0).frame, goals.frame)
        let dismissed = NSPredicate { _, _ in !addFirstGoal.isHittable }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: dismissed, object: nil)], timeout: 5), .completed)
    }

    private func launch(state: String) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-test-state", state]
        app.launch()
    }

    private func openGoalsFromNoGoals() {
        launch(state: "no-goals")
        openMenuBarExtra()
        let addFirstGoal = app.buttons["mrrclock.add-first-goal"]
        XCTAssertTrue(addFirstGoal.waitForExistence(timeout: 5))
        addFirstGoal.click()
        XCTAssertTrue(app.windows["Goals"].waitForExistence(timeout: 5))
    }

    private func openMenuBarExtra() {
        let statusItem = app.menuBars.statusItems["mrrclock.menu-bar-item"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
    }

    private func openMenuBarExtra(revealing buttonIdentifier: String) -> XCUIElement {
        openMenuBarExtra()
        let button = app.buttons[buttonIdentifier]
        if !button.waitForExistence(timeout: 1) {
            openMenuBarExtra()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        return button
    }
}
