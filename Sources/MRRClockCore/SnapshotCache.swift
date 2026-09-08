import Foundation

/// Persistence seam for the last good snapshot (docs/ARCHITECTURE.md § Storage).
public protocol SnapshotStorage: Sendable {
    func load() throws -> Snapshot?
    func write(_ snapshot: Snapshot) throws
}

/// Deterministic in-memory snapshot persistence for tests and previews.
public final class InMemorySnapshotCache: SnapshotStorage, @unchecked Sendable {
    public private(set) var snapshot: Snapshot?
    public private(set) var writeCount = 0

    public init(snapshot: Snapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() throws -> Snapshot? { snapshot }

    public func write(_ snapshot: Snapshot) throws {
        self.snapshot = snapshot
        writeCount += 1
    }
}

/// JSON-backed snapshot persistence at the location specified by docs/ARCHITECTURE.md.
public struct FileSnapshotCache: SnapshotStorage {
    private let directory: URL

    public init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MRRClock", isDirectory: true)) {
        self.directory = directory
    }

    public func load() throws -> Snapshot? {
        let url = directory.appendingPathComponent("snapshot.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
            guard snapshot.specVersion == metricsSpecVersion else { return nil }
            return snapshot
        } catch {
            let corruptURL = directory.appendingPathComponent("snapshot.corrupt.json")
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                try FileManager.default.removeItem(at: corruptURL)
            }
            try FileManager.default.moveItem(at: url, to: corruptURL)
            return nil
        }
    }

    public func write(_ snapshot: Snapshot) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("snapshot.json")
        let temporary = directory.appendingPathComponent("snapshot.\(UUID().uuidString).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: temporary)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}
