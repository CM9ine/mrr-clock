import Foundation

/// Resolves the inspectable storage directory required by docs/ARCHITECTURE.md § Storage.
public struct StorageLocations: Equatable, Sendable {
    public let directory: URL
    public let legacyDirectory: URL
    public var goalURL: URL { directory.appendingPathComponent("goals.json") }
    public var snapshotURL: URL { directory.appendingPathComponent("snapshot.json") }
    public var legacyGoalURL: URL { legacyDirectory.appendingPathComponent("goals.json") }
    public var legacySnapshotURL: URL { legacyDirectory.appendingPathComponent("snapshot.json") }

    public init(homeDirectory: URL) {
        self.init(
            applicationSupportDirectory: homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true),
            legacyDirectory: homeDirectory
                .appendingPathComponent("Library/Containers/com.mrrclock.app/Data/Library/Application Support/MRRClock", isDirectory: true)
        )
    }

    public init(applicationSupportDirectory: URL) {
        self.init(
            applicationSupportDirectory: applicationSupportDirectory,
            legacyDirectory: applicationSupportDirectory.appendingPathComponent("MRRClock", isDirectory: true)
        )
    }

    public init(applicationSupportDirectory: URL, legacyDirectory: URL) {
        directory = applicationSupportDirectory.appendingPathComponent("MRRClock", isDirectory: true)
        self.legacyDirectory = legacyDirectory
    }
}

/// Injectable destination writer used to keep legacy data readable if migration fails.
public protocol StorageMigrationWriting: Sendable {
    func write(_ data: Data, to destination: URL) throws
}

/// Atomically installs migrated bytes without deleting their source copy.
public struct AtomicStorageMigrationWriter: StorageMigrationWriting {
    public init() {}

    public func write(_ data: Data, to destination: URL) throws {
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent("migration.\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        do {
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}

/// Migrates sandbox-container files to the inspectable paths in docs/ARCHITECTURE.md § Storage.
public struct StorageMigrator: Sendable {
    private let locations: StorageLocations
    private let writer: any StorageMigrationWriting

    public init(locations: StorageLocations, writer: any StorageMigrationWriting = AtomicStorageMigrationWriter()) {
        self.locations = locations
        self.writer = writer
    }

    public func migrate() throws {
        try migrate(from: locations.legacyGoalURL, to: locations.goalURL)
        try migrate(from: locations.legacySnapshotURL, to: locations.snapshotURL)
    }

    private func migrate(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) else { return }
        try writer.write(Data(contentsOf: source), to: destination)
    }
}
