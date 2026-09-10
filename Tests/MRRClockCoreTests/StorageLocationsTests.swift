import Foundation
import Testing
@testable import MRRClockCore

struct StorageLocationsTests {
    private struct FailingWriter: StorageMigrationWriting {
        struct Failure: Error {}
        func write(_ data: Data, to destination: URL) throws { throw Failure() }
    }

    private func temporaryLocations() throws -> (root: URL, locations: StorageLocations) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MRRClock-Migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, StorageLocations(
            applicationSupportDirectory: root.appendingPathComponent("Current", isDirectory: true),
            legacyDirectory: root.appendingPathComponent("Legacy/MRRClock", isDirectory: true)
        ))
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            syncedAt: Date(iso: "2026-09-07T09:00:00Z"),
            revenue: RevenueSnapshot(
                mrr: Money(12_345, "usd"), earnedToDate: Money(25_000, "usd"), breakdown: [],
                subscriptionCount: 4, churnRisk: Money(1_000, "usd"), warnings: []
            ),
            goals: [],
            specVersion: metricsSpecVersion
        )
    }

    @Test("production directory is MRRClock under user Application Support")
    func productionDirectory() {
        let locations = StorageLocations(homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true))

        #expect(locations.directory.path == "/Users/example/Library/Application Support/MRRClock")
    }

    @Test("goal and snapshot URLs share the production directory")
    func storeURLs() {
        let locations = StorageLocations(homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true))

        #expect(locations.goalURL == locations.directory.appendingPathComponent("goals.json"))
        #expect(locations.snapshotURL == locations.directory.appendingPathComponent("snapshot.json"))
    }

    @Test("migrates legacy goals when the destination is absent")
    func migratesLegacyGoals() throws {
        let (root, locations) = try temporaryLocations()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: locations.legacyDirectory, withIntermediateDirectories: true)
        let instant = Date(iso: "2026-09-07T00:00:00Z")
        let goal = Goal(name: "Legacy goal", targetDate: instant, createdAt: instant, sortIndex: 0)
        let expected = GoalFile(goals: [goal], pinnedGoalID: goal.id)
        try JSONEncoder().encode(expected).write(to: locations.legacyGoalURL)

        try StorageMigrator(locations: locations).migrate()

        let migrated = try JSONDecoder().decode(GoalFile.self, from: Data(contentsOf: locations.goalURL))
        #expect(migrated == expected)
    }

    @Test("migrates the legacy snapshot when the destination is absent")
    func migratesLegacySnapshot() throws {
        let (root, locations) = try temporaryLocations()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: locations.legacyDirectory, withIntermediateDirectories: true)
        let expected = snapshot()
        try JSONEncoder().encode(expected).write(to: locations.legacySnapshotURL)

        try StorageMigrator(locations: locations).migrate()

        let migrated = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: locations.snapshotURL))
        #expect(migrated == expected)
    }

    @Test("does not overwrite an existing destination during migration")
    func preservesExistingDestination() throws {
        let (root, locations) = try temporaryLocations()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: locations.legacyDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: locations.directory, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: locations.legacyGoalURL)
        let expected = Data("newer destination".utf8)
        try expected.write(to: locations.goalURL)

        try StorageMigrator(locations: locations).migrate()

        #expect(try Data(contentsOf: locations.goalURL) == expected)
    }

    @Test("migration is idempotent")
    func migrationIsIdempotent() throws {
        let (root, locations) = try temporaryLocations()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: locations.legacyDirectory, withIntermediateDirectories: true)
        let expected = Data("legacy goals".utf8)
        try expected.write(to: locations.legacyGoalURL)

        let migrator = StorageMigrator(locations: locations)
        try migrator.migrate()
        let first = try Data(contentsOf: locations.goalURL)
        try migrator.migrate()

        #expect(try Data(contentsOf: locations.goalURL) == first)
        #expect(first == expected)
        let files = try FileManager.default.contentsOfDirectory(atPath: locations.directory.path)
        #expect(files == ["goals.json"])
    }

    @Test("failed migration preserves the legacy file")
    func failedMigrationPreservesLegacyFile() throws {
        let (root, locations) = try temporaryLocations()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: locations.legacyDirectory, withIntermediateDirectories: true)
        let expected = Data("only readable copy".utf8)
        try expected.write(to: locations.legacyGoalURL)

        #expect(throws: FailingWriter.Failure.self) {
            try StorageMigrator(locations: locations, writer: FailingWriter()).migrate()
        }

        #expect(try Data(contentsOf: locations.legacyGoalURL) == expected)
        #expect(!FileManager.default.fileExists(atPath: locations.goalURL.path))
    }
}
