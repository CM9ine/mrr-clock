import Foundation
import Testing
@testable import MRRClockCore

struct FileGoalStoreTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MRRClock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("goal store uses the injected storage directory")
    func usesInjectedStorageDirectory() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let locations = StorageLocations(applicationSupportDirectory: root)

        try FileGoalStore(locations: locations).save(GoalFile())

        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("MRRClock/goals.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("goals.json").path))
    }

    @Test("creates the file on first save")
    func createsFile() throws {
        let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
        try FileGoalStore(directory: url).save(GoalFile())
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("goals.json").path))
    }

    @Test("loads an empty file as no goals")
    func missingFileIsEmpty() throws {
        let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
        #expect(try FileGoalStore(directory: url).load() == GoalFile())
    }

    @Test("round-trips goals through disk")
    func diskRoundTrip() throws {
        let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
        let instant = Date(iso: "2026-09-07T00:00:00Z")
        let goals = (0..<3).map { Goal(name: "G\($0)", targetDate: instant, targetAmount: Money(100 + $0, "usd"), createdAt: instant, sortIndex: $0) }
        try FileGoalStore(directory: url).save(GoalFile(goals: goals, pinnedGoalID: goals[1].id))
        #expect(try FileGoalStore(directory: url).load() == GoalFile(goals: goals, pinnedGoalID: goals[1].id))
    }

    @Test("recovers from a corrupt file")
    func corruptRecovery() throws {
        let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ not json".utf8).write(to: url.appendingPathComponent("goals.json"))
        #expect(try FileGoalStore(directory: url).load() == GoalFile())
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("goals.corrupt.json").path))
    }

    @Test("writes atomically")
    func atomicWritesRemainJSON() throws {
        let url = try directory(); defer { try? FileManager.default.removeItem(at: url) }
        let storage = FileGoalStore(directory: url)
        for index in 0..<20 {
            let instant = Date(iso: "2026-09-07T00:00:00Z")
            let goal = Goal(name: "G\(index)", targetDate: instant, createdAt: instant, sortIndex: 0)
            try storage.save(GoalFile(goals: [goal], pinnedGoalID: goal.id))
            let data = try Data(contentsOf: url.appendingPathComponent("goals.json"))
            #expect(!data.isEmpty)
            #expect(throws: Never.self) { try JSONDecoder().decode(GoalFile.self, from: data) }
        }
    }
}
