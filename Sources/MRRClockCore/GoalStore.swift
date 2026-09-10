import Foundation

/// Persisted goal data described by docs/ARCHITECTURE.md § Storage.
public struct GoalFile: Codable, Equatable, Sendable {
    public var goals: [Goal]
    public var pinnedGoalID: UUID?

    public init(goals: [Goal] = [], pinnedGoalID: UUID? = nil) {
        self.goals = goals
        self.pinnedGoalID = pinnedGoalID
    }
}

/// Storage seam for user-authored goals (docs/ARCHITECTURE.md § Storage).
public protocol GoalStorage: Sendable {
    func load() throws -> GoalFile
    func save(_ file: GoalFile) throws
}

/// Errors from goal mutations governed by docs/METRICS.md § Goal.
public enum GoalStoreError: Error, Equatable {
    case invalid(GoalValidation)
    case unknownGoal(UUID)
}

/// CRUD, ordering, pinning, and immediate persistence for docs/METRICS.md § Goal.
public final class GoalStore: @unchecked Sendable {
    private let storage: any GoalStorage
    private let clock: any Clock
    private let config: Config
    private var file: GoalFile

    public init(storage: any GoalStorage, clock: any Clock, config: Config = Config()) {
        self.storage = storage
        self.clock = clock
        self.config = config
        file = (try? storage.load()) ?? GoalFile()
    }

    public var goals: [Goal] { file.goals.sorted { $0.sortIndex < $1.sortIndex } }
    public var pinned: Goal? { goals.first { $0.id == file.pinnedGoalID } }

    @discardableResult
    public func add(name: String, targetDate: Date, targetAmount: Money?) throws -> Goal {
        try requireValid(name: name, amount: targetAmount)
        let goal = Goal(name: name, targetDate: targetDate, targetAmount: targetAmount, createdAt: clock.now, sortIndex: goals.count)
        file.goals.append(goal)
        if file.goals.count == 1 { file.pinnedGoalID = goal.id }
        try storage.save(file)
        return goal
    }

    public func update(_ goal: Goal) throws {
        try requireValid(name: goal.name, amount: goal.targetAmount)
        guard let index = file.goals.firstIndex(where: { $0.id == goal.id }) else { throw GoalStoreError.unknownGoal(goal.id) }
        var trimmed = goal
        trimmed.name = goal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        file.goals[index] = trimmed
        try storage.save(file)
    }

    public func delete(id: UUID) throws {
        let ordered = goals
        guard let orderedIndex = ordered.firstIndex(where: { $0.id == id }) else { return }
        let wasPinned = file.pinnedGoalID == id
        file.goals = ordered.filter { $0.id != id }
        renumber()
        if wasPinned {
            let remaining = goals
            file.pinnedGoalID = remaining.isEmpty ? nil : remaining[min(orderedIndex, remaining.count - 1)].id
        }
        try storage.save(file)
    }

    public func move(from offsets: IndexSet, to destination: Int) throws {
        var ordered = goals
        let moving = offsets.sorted().map { ordered[$0] }
        for index in offsets.sorted(by: >) { ordered.remove(at: index) }
        let adjusted = destination - offsets.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: max(0, min(adjusted, ordered.count)))
        file.goals = ordered
        renumber()
        try storage.save(file)
    }

    public func pin(id: UUID) throws {
        guard file.goals.contains(where: { $0.id == id }) else { throw GoalStoreError.unknownGoal(id) }
        file.pinnedGoalID = id
        try storage.save(file)
    }

    private func requireValid(name: String, amount: Money?) throws {
        let result = Goal.validate(name: name, targetAmount: amount, config: config)
        guard result == .valid else { throw GoalStoreError.invalid(result) }
    }

    private func renumber() {
        file.goals = file.goals.enumerated().map { index, goal in
            var goal = goal
            goal.sortIndex = index
            return goal
        }
    }
}

/// Deterministic in-memory goal persistence for tests and previews.
public final class InMemoryGoalStore: GoalStorage, @unchecked Sendable {
    private var file: GoalFile
    public private(set) var saveCount = 0

    public init(file: GoalFile = GoalFile()) { self.file = file }
    public func load() throws -> GoalFile { file }
    public func save(_ file: GoalFile) throws { self.file = file; saveCount += 1 }
}

/// JSON-backed goal persistence at the location specified by docs/ARCHITECTURE.md § Storage.
public struct FileGoalStore: GoalStorage {
    private let directory: URL

    public init(locations: StorageLocations) {
        directory = locations.directory
    }

    public init(directory: URL) {
        self.directory = directory
    }

    public func load() throws -> GoalFile {
        let fileManager = FileManager.default
        let url = directory.appendingPathComponent("goals.json")
        guard fileManager.fileExists(atPath: url.path) else { return GoalFile() }
        do {
            return try JSONDecoder().decode(GoalFile.self, from: Data(contentsOf: url))
        } catch {
            let corruptURL = directory.appendingPathComponent("goals.corrupt.json")
            if fileManager.fileExists(atPath: corruptURL.path) { try fileManager.removeItem(at: corruptURL) }
            try fileManager.moveItem(at: url, to: corruptURL)
            return GoalFile()
        }
    }

    public func save(_ file: GoalFile) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("goals.json")
        let temporary = directory.appendingPathComponent("goals.\(UUID().uuidString).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: temporary)
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
