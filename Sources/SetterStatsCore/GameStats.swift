import Foundation

public enum Stat: String, CaseIterable, Identifiable {
    case attacks = "Attacks"
    case serves = "Serves"
    case digs = "Digs"
    case errors = "Errors"
    case serviceErrors = "Service Errors"

    public var id: String { rawValue }
}

/// Where on the court the set was delivered from. These are court set
/// locations, independent of the match's game-set number (best-of-5).
public enum AssistLocation: String, CaseIterable, Identifiable, Codable {
    case front = "Front Set"
    case back = "Back Set"
    case middle = "Middle Set"
    case backRow = "Back Row Set"

    public var id: String { rawValue }
}

/// Assist quality. The numeric `code` matches the on-screen quick buttons
/// (1 / 2 / 3).
public enum AssistQuality: String, CaseIterable, Identifiable, Codable {
    case perfect = "Perfect"
    case decent = "Decent"
    case offTheMark = "Off the Mark"

    public var id: String { rawValue }

    public var code: Int {
        switch self {
        case .perfect: return 1
        case .decent: return 2
        case .offTheMark: return 3
        }
    }
}

public struct AssistKey: Hashable, Equatable, Codable {
    public let location: AssistLocation
    public let quality: AssistQuality

    public init(location: AssistLocation, quality: AssistQuality) {
        self.location = location
        self.quality = quality
    }
}

public struct SetRecord: Equatable, Codable {
    public let setNumber: Int
    public let opponent: String
    public let assists: [AssistKey: Int]
    public let attacks: Int
    public let serves: Int
    public let aces: Int
    public let digs: Int
    public let errors: Int
    public let serviceErrors: Int

    public init(
        setNumber: Int,
        opponent: String = "",
        assists: [AssistKey: Int],
        attacks: Int,
        serves: Int,
        aces: Int,
        digs: Int,
        errors: Int,
        serviceErrors: Int
    ) {
        self.setNumber = setNumber
        self.opponent = opponent
        self.assists = assists
        self.attacks = attacks
        self.serves = serves
        self.aces = aces
        self.digs = digs
        self.errors = errors
        self.serviceErrors = serviceErrors
    }

    public func value(for stat: Stat) -> Int {
        switch stat {
        case .attacks: return attacks
        case .serves: return serves
        case .digs: return digs
        case .errors: return errors
        case .serviceErrors: return serviceErrors
        }
    }

    public func assistValue(location: AssistLocation, quality: AssistQuality) -> Int {
        assists[AssistKey(location: location, quality: quality)] ?? 0
    }
}

public struct GameStats: Equatable, Codable {
    /// Varsity volleyball is best-of-5, so a match tracks Set 1 through Set 5.
    public static let maxSetNumber = 5

    /// UserDefaults / local-storage key. No cloud sync, no credentials.
    public static let persistenceKey = "setter-stats-game"

    private enum CodingKeys: String, CodingKey {
        case opponent, setNumber, assists, attacks, serves, aces, digs, errors, serviceErrors, savedSets
    }

    public private(set) var opponent = ""
    public private(set) var setNumber = 1
    public private(set) var assists: [AssistKey: Int] = [:]
    public private(set) var attacks = 0
    public private(set) var serves = 0
    public private(set) var aces = 0
    public private(set) var digs = 0
    public private(set) var errors = 0
    public private(set) var serviceErrors = 0
    public private(set) var savedSets: [SetRecord] = []
    private var history: [Snapshot] = []

    private struct Snapshot: Equatable {
        let opponent: String
        let setNumber: Int
        let assists: [AssistKey: Int]
        let attacks: Int
        let serves: Int
        let aces: Int
        let digs: Int
        let errors: Int
        let serviceErrors: Int
        let savedSets: [SetRecord]
    }

    public init() {}

    public func value(for stat: Stat) -> Int {
        switch stat {
        case .attacks: return attacks
        case .serves: return serves
        case .digs: return digs
        case .errors: return errors
        case .serviceErrors: return serviceErrors
        }
    }

    public func assistValue(location: AssistLocation, quality: AssistQuality) -> Int {
        assists[AssistKey(location: location, quality: quality)] ?? 0
    }

    public var totalAssists: Int {
        assists.values.reduce(0, +)
    }

    public func cumulativeAssist(location: AssistLocation, quality: AssistQuality) -> Int {
        assistValue(location: location, quality: quality)
            + savedSets.reduce(0) { $0 + $1.assistValue(location: location, quality: quality) }
    }

    public var canUndo: Bool { !history.isEmpty }

    public mutating func increment(_ stat: Stat) { change(stat, by: 1); persist() }
    public mutating func decrement(_ stat: Stat) { change(stat, by: -1); persist() }

    public mutating func recordAssist(location: AssistLocation, quality: AssistQuality) {
        saveSnapshot()
        let key = AssistKey(location: location, quality: quality)
        assists[key, default: 0] += 1
        persist()
    }

    public mutating func recordAce() {
        saveSnapshot()
        aces += 1
        serves += 1
        persist()
    }

    public mutating func recordServiceError() {
        saveSnapshot()
        serviceErrors += 1
        serves += 1
        persist()
    }

    public mutating func setOpponent(_ value: String) {
        let trimmed = value
        if trimmed == opponent { return }
        saveSnapshot()
        opponent = trimmed
        persist()
    }

    public mutating func setSetNumber(_ value: Int) {
        let clamped = min(GameStats.maxSetNumber, max(1, value))
        if clamped == setNumber { return }
        saveSnapshot()
        setNumber = clamped
        persist()
    }

    /// True while there is a next set to advance to (i.e. before Set 5).
    public var canFinalizeCurrentSet: Bool {
        setNumber < GameStats.maxSetNumber
    }

    /// Moves back one set without destroying saved data or resetting counters.
    public mutating func decrementSetNumber() {
        if setNumber <= 1 { return }
        saveSnapshot()
        setNumber -= 1
        persist()
    }

    /// Stores the current set's counters into `savedSets` and resets the live
    /// counters to zero. Used both when advancing and when finishing a match.
    public mutating func saveCurrentSet() {
        let finalized = setNumber
        saveSnapshot()
        savedSets.append(SetRecord(
            setNumber: finalized,
            opponent: opponent,
            assists: assists,
            attacks: attacks,
            serves: serves,
            aces: aces,
            digs: digs,
            errors: errors,
            serviceErrors: serviceErrors
        ))
        resetCounters()
        persist()
    }

    /// Asks (via caller) to save the current set, then resets all current entry
    /// counters to zero and advances to the next set. Does not advance beyond
    /// `maxSetNumber` — when called on the final set it only saves and resets.
    /// Callers should confirm with the user before invoking this.
    @discardableResult
    public mutating func finalizeCurrentSet() -> Int {
        let finalized = setNumber
        guard !savedSets.contains(where: { $0.setNumber == finalized }) else {
            return finalized
        }
        saveCurrentSet()
        if setNumber < GameStats.maxSetNumber {
            setNumber = finalized + 1
        }
        persist()
        return finalized
    }

    public func cumulativeValue(for stat: Stat) -> Int {
        value(for: stat) + savedSets.reduce(0) { $0 + $1.value(for: stat) }
    }

    private mutating func resetCounters() {
        assists = [:]
        attacks = 0
        serves = 0
        aces = 0
        digs = 0
        errors = 0
        serviceErrors = 0
    }

    public mutating func undoLastAction() {
        guard let previous = history.popLast() else { return }
        opponent = previous.opponent
        setNumber = previous.setNumber
        assists = previous.assists
        attacks = previous.attacks
        serves = previous.serves
        aces = previous.aces
        digs = previous.digs
        errors = previous.errors
        serviceErrors = previous.serviceErrors
        savedSets = previous.savedSets
        persist()
    }

    public mutating func reset() {
        opponent = ""
        setNumber = 1
        resetCounters()
        savedSets = []
        history = []
        persist()
    }

    private mutating func change(_ stat: Stat, by amount: Int) {
        if amount < 0 && value(for: stat) == 0 { return }
        saveSnapshot()
        switch stat {
        case .attacks: attacks = max(0, attacks + amount)
        case .serves: serves = max(0, serves + amount)
        case .digs: digs = max(0, digs + amount)
        case .errors: errors = max(0, errors + amount)
        case .serviceErrors: serviceErrors = max(0, serviceErrors + amount)
        }
    }

    private mutating func saveSnapshot() {
        history.append(Snapshot(
            opponent: opponent,
            setNumber: setNumber,
            assists: assists,
            attacks: attacks,
            serves: serves,
            aces: aces,
            digs: digs,
            errors: errors,
            serviceErrors: serviceErrors,
            savedSets: savedSets
        ))
    }

    // MARK: - Normalization & Local Persistence

    /// Returns a cleaned copy with complete assist maps, clamped set number,
    /// and well-formed saved sets. Mirrors the web app's migration step so the
    /// two platforms stay consistent.
    public func normalized() -> GameStats {
        var clean = GameStats()
        clean.opponent = opponent
        clean.setNumber = min(GameStats.maxSetNumber, max(1, setNumber))
        for location in AssistLocation.allCases {
            for quality in AssistQuality.allCases {
                let v = assistValue(location: location, quality: quality)
                if v > 0 { clean.assists[AssistKey(location: location, quality: quality)] = v }
            }
        }
        clean.attacks = max(0, attacks)
        clean.serves = max(0, serves)
        clean.aces = max(0, aces)
        clean.digs = max(0, digs)
        clean.errors = max(0, errors)
        clean.serviceErrors = max(0, serviceErrors)
        clean.savedSets = savedSets.map { record in
            var rec = SetRecord(
                setNumber: max(1, min(GameStats.maxSetNumber, record.setNumber)),
                opponent: record.opponent,
                assists: [:],
                attacks: max(0, record.attacks),
                serves: max(0, record.serves),
                aces: max(0, record.aces),
                digs: max(0, record.digs),
                errors: max(0, record.errors),
                serviceErrors: max(0, record.serviceErrors)
            )
            var assists: [AssistKey: Int] = [:]
            for location in AssistLocation.allCases {
                for quality in AssistQuality.allCases {
                    let v = record.assistValue(location: location, quality: quality)
                    if v > 0 { assists[AssistKey(location: location, quality: quality)] = v }
                }
            }
            rec = SetRecord(
                setNumber: rec.setNumber,
                opponent: rec.opponent,
                assists: assists,
                attacks: rec.attacks,
                serves: rec.serves,
                aces: rec.aces,
                digs: rec.digs,
                errors: rec.errors,
                serviceErrors: rec.serviceErrors
            )
            return rec
        }
        return clean
    }

    /// Writes the (normalized) state to local storage. No network, no credentials.
    public func persist(to defaults: UserDefaults = .standard) {
        let normalized = normalized()
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(normalized) {
            defaults.set(data, forKey: GameStats.persistenceKey)
        }
    }

    /// Loads persisted state, normalizes it, writes the normalized copy back, and
    /// returns it. Falls back to a fresh game when nothing is stored or decoding fails.
    public static func load(from defaults: UserDefaults = .standard) -> GameStats {
        guard let data = defaults.data(forKey: GameStats.persistenceKey) else {
            return GameStats()
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(GameStats.self, from: data) else {
            return GameStats()
        }
        let normalized = decoded.normalized()
        normalized.persist(to: defaults)
        return normalized
    }
}
