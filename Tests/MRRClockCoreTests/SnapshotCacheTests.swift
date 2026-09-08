import Foundation
import Testing
@testable import MRRClockCore

struct SnapshotCacheTests {
    private let instant = Date(iso: "2026-09-07T09:00:00Z")

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MRRClock-Snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snapshot(specVersion: Int = metricsSpecVersion, mrr: Int = 12_345) -> Snapshot {
        Snapshot(
            syncedAt: instant,
            revenue: RevenueSnapshot(
                mrr: Money(mrr, "usd"),
                earnedToDate: Money(25_000, "usd"),
                breakdown: [ProductLine(productID: "prod_1", name: "Product", amount: Money(mrr, "usd"))],
                subscriptionCount: 4,
                churnRisk: Money(1_000, "usd"),
                warnings: ["Skipped price price_1: metered"]
            ),
            goals: [GoalProgress(
                goalID: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
                name: "Goal",
                targetDate: Date(iso: "2027-09-07T00:00:00Z"),
                targetAmount: Money(100_000, "usd"),
                daysRemaining: 365,
                projected: Money(120_000, "usd"),
                percentFunded: Decimal(string: "0.25")!,
                percentOnTrack: Decimal(string: "1.2")!,
                isPinned: true
            )],
            specVersion: specVersion
        )
    }

    @Test("returns nil when nothing is cached")
    func missingCache() throws {
        let url = try directory()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try FileSnapshotCache(directory: url).load() == nil)
    }

    @Test("round-trips a snapshot through disk")
    func diskRoundTrip() throws {
        let url = try directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = FileSnapshotCache(directory: url)
        let expected = snapshot()

        try cache.write(expected)

        #expect(try cache.load() == expected)
    }

    @Test("overwrites the previous snapshot")
    func overwritesSnapshot() throws {
        let url = try directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = FileSnapshotCache(directory: url)

        try cache.write(snapshot(mrr: 10_000))
        try cache.write(snapshot(mrr: 20_000))

        #expect(try cache.load() == snapshot(mrr: 20_000))
    }

    @Test("returns nil and quarantines a corrupt file")
    func quarantinesCorruptFile() throws {
        let url = try directory()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ not json".utf8).write(to: url.appendingPathComponent("snapshot.json"))

        #expect(try FileSnapshotCache(directory: url).load() == nil)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("snapshot.corrupt.json").path))
    }

    @Test("ignores a snapshot from an older spec version")
    func ignoresOldSpec() throws {
        let url = try directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = FileSnapshotCache(directory: url)
        try cache.write(snapshot(specVersion: 0))

        #expect(try cache.load() == nil)
    }

    @Test("reports staleness against the clock")
    func reportsStaleness() {
        let cached = snapshot()

        #expect(!cached.isStale(
            now: instant.addingTimeInterval(14 * 60), maxAge: 15 * 60
        ))
        #expect(cached.isStale(
            now: instant.addingTimeInterval(16 * 60), maxAge: 15 * 60
        ))
    }
}
