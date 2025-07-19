//
//  SmartPlaylistRule.swift
//  WinAmpPlayer
//
//  Created on 2025-07-02.
//  Defines rule types for smart playlist filtering.
//

import Foundation

/// Protocol for all smart playlist rules
public protocol SmartPlaylistRuleProtocol: Codable {
    /// Evaluates whether a track matches this rule
    func evaluate(track: Track) -> Bool
    
    /// A human-readable description of this rule
    var description: String { get }
    
    /// Whether this rule requires indexing for performance
    var requiresIndexing: Bool { get }
}

/// Comparison operators for rules
public enum ComparisonOperator: String, Codable, CaseIterable {
    case equals = "equals"
    case notEquals = "notEquals"
    case contains = "contains"
    case notContains = "notContains"
    case startsWith = "startsWith"
    case endsWith = "endsWith"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case greaterThanOrEqual = "greaterThanOrEqual"
    case lessThanOrEqual = "lessThanOrEqual"
    case between = "between"
    case inList = "inList"
    case notInList = "notInList"
    
    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .contains: return "contains"
        case .notContains: return "does not contain"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .greaterThan: return "is greater than"
        case .lessThan: return "is less than"
        case .greaterThanOrEqual: return "is at least"
        case .lessThanOrEqual: return "is at most"
        case .between: return "is between"
        case .inList: return "is in"
        case .notInList: return "is not in"
        }
    }
}

/// Date comparison units
public enum DateUnit: String, Codable, CaseIterable {
    case days = "days"
    case weeks = "weeks"
    case months = "months"
    case years = "years"
}

// MARK: - Metadata Rules

/// Rule for string metadata fields
public struct StringMetadataRule: SmartPlaylistRuleProtocol {
    public enum Field: String, Codable, CaseIterable {
        case title, artist, album, genre, albumArtist, composer, comment, encoder
        
        var displayName: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .album: return "Album"
            case .genre: return "Genre"
            case .albumArtist: return "Album Artist"
            case .composer: return "Composer"
            case .comment: return "Comment"
            case .encoder: return "Encoder"
            }
        }
    }
    
    let field: Field
    let `operator`: ComparisonOperator
    let value: String
    let caseSensitive: Bool
    
    public init(field: Field, operator: ComparisonOperator, value: String, caseSensitive: Bool = false) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.caseSensitive = caseSensitive
    }
    
    public func evaluate(track: Track) -> Bool {
        let fieldValue: String? = {
            switch field {
            case .title: return track.title
            case .artist: return track.artist
            case .album: return track.album
            case .genre: return track.genre
            case .albumArtist: return track.albumArtist
            case .composer: return track.composer
            case .comment: return track.comment
            case .encoder: return track.encoder
            }
        }()
        
        guard let fieldValue = fieldValue else {
            return `operator` == .notEquals || `operator` == .notContains || `operator` == .notInList
        }
        
        let compareValue = caseSensitive ? fieldValue : fieldValue.lowercased()
        let targetValue = caseSensitive ? value : value.lowercased()
        
        switch `operator` {
        case .equals:
            return compareValue == targetValue
        case .notEquals:
            return compareValue != targetValue
        case .contains:
            return compareValue.contains(targetValue)
        case .notContains:
            return !compareValue.contains(targetValue)
        case .startsWith:
            return compareValue.hasPrefix(targetValue)
        case .endsWith:
            return compareValue.hasSuffix(targetValue)
        case .inList:
            let list = targetValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return list.contains(compareValue)
        case .notInList:
            let list = targetValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return !list.contains(compareValue)
        default:
            return false
        }
    }
    
    public var description: String {
        "\(field.displayName) \(`operator`.displayName) \"\(value)\""
    }
    
    public var requiresIndexing: Bool {
        `operator` == .contains || `operator` == .notContains
    }
}

/// Rule for numeric metadata fields
public struct NumericMetadataRule: SmartPlaylistRuleProtocol {
    public enum Field: String, Codable, CaseIterable {
        case year, trackNumber, discNumber, bpm, duration
        
        var displayName: String {
            switch self {
            case .year: return "Year"
            case .trackNumber: return "Track Number"
            case .discNumber: return "Disc Number"
            case .bpm: return "BPM"
            case .duration: return "Duration"
            }
        }
    }
    
    let field: Field
    let `operator`: ComparisonOperator
    let value: Double
    let secondValue: Double? // For between operator
    
    public init(field: Field, operator: ComparisonOperator, value: Double, secondValue: Double? = nil) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.secondValue = secondValue
    }
    
    public func evaluate(track: Track) -> Bool {
        let fieldValue: Double? = {
            switch field {
            case .year: return track.year.map(Double.init)
            case .trackNumber: return track.trackNumber.map(Double.init)
            case .discNumber: return track.discNumber.map(Double.init)
            case .bpm: return track.bpm.map(Double.init)
            case .duration: return track.duration
            }
        }()
        
        guard let fieldValue = fieldValue else {
            return `operator` == .notEquals
        }
        
        switch `operator` {
        case .equals:
            return fieldValue == value
        case .notEquals:
            return fieldValue != value
        case .greaterThan:
            return fieldValue > value
        case .lessThan:
            return fieldValue < value
        case .greaterThanOrEqual:
            return fieldValue >= value
        case .lessThanOrEqual:
            return fieldValue <= value
        case .between:
            guard let secondValue = secondValue else { return false }
            return fieldValue >= value && fieldValue <= secondValue
        default:
            return false
        }
    }
    
    public var description: String {
        if `operator` == .between, let secondValue = secondValue {
            return "\(field.displayName) \(`operator`.displayName) \(value) and \(secondValue)"
        }
        return "\(field.displayName) \(`operator`.displayName) \(value)"
    }
    
    public var requiresIndexing: Bool { false }
}

// MARK: - File Property Rules

/// Rule for file properties
public struct FilePropertyRule: SmartPlaylistRuleProtocol {
    public enum Field: String, Codable, CaseIterable {
        case fileSize, dateAdded, format
        
        var displayName: String {
            switch self {
            case .fileSize: return "File Size"
            case .dateAdded: return "Date Added"
            case .format: return "Format"
            }
        }
    }
    
    let field: Field
    let `operator`: ComparisonOperator
    let value: Any
    let unit: DateUnit?
    
    private enum CodingKeys: String, CodingKey {
        case field, `operator`, unit
        case stringValue, doubleValue, dateValue
    }
    
    public init(field: Field, operator: ComparisonOperator, fileSize: Double) {
        self.field = field
        self.operator = `operator`
        self.value = fileSize
        self.unit = nil
    }
    
    public init(field: Field, operator: ComparisonOperator, format: AudioFormat) {
        self.field = field
        self.operator = `operator`
        self.value = format.rawValue
        self.unit = nil
    }
    
    public init(field: Field, operator: ComparisonOperator, dateValue: Double, unit: DateUnit) {
        self.field = field
        self.operator = `operator`
        self.value = dateValue
        self.unit = unit
    }
    
    public func evaluate(track: Track) -> Bool {
        switch field {
        case .fileSize:
            guard let fileSize = track.fileSize,
                  let compareValue = value as? Double else { return false }
            let fileSizeMB = Double(fileSize) / (1024 * 1024)
            
            switch `operator` {
            case .equals: return fileSizeMB == compareValue
            case .notEquals: return fileSizeMB != compareValue
            case .greaterThan: return fileSizeMB > compareValue
            case .lessThan: return fileSizeMB < compareValue
            case .greaterThanOrEqual: return fileSizeMB >= compareValue
            case .lessThanOrEqual: return fileSizeMB <= compareValue
            default: return false
            }
            
        case .dateAdded:
            guard let dateAdded = track.dateAdded,
                  let compareValue = value as? Double,
                  let unit = unit else { return false }
            
            let calendar = Calendar.current
            let now = Date()
            var dateComponent = DateComponents()
            
            switch unit {
            case .days: dateComponent.day = -Int(compareValue)
            case .weeks: dateComponent.weekOfYear = -Int(compareValue)
            case .months: dateComponent.month = -Int(compareValue)
            case .years: dateComponent.year = -Int(compareValue)
            }
            
            guard let compareDate = calendar.date(byAdding: dateComponent, to: now) else { return false }
            
            switch `operator` {
            case .greaterThan: return dateAdded > compareDate
            case .lessThan: return dateAdded < compareDate
            case .greaterThanOrEqual: return dateAdded >= compareDate
            case .lessThanOrEqual: return dateAdded <= compareDate
            default: return false
            }
            
        case .format:
            guard let format = track.audioFormat,
                  let compareValue = value as? String else { return false }
            
            switch `operator` {
            case .equals: return format.rawValue == compareValue
            case .notEquals: return format.rawValue != compareValue
            case .inList:
                let formats = compareValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return formats.contains(format.rawValue)
            case .notInList:
                let formats = compareValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return !formats.contains(format.rawValue)
            default: return false
            }
        }
    }
    
    public var description: String {
        switch field {
        case .fileSize:
            return "\(field.displayName) \(`operator`.displayName) \(value) MB"
        case .dateAdded:
            guard let unit = unit else { return "\(field.displayName) \(`operator`.displayName) \(value)" }
            return "\(field.displayName) in the last \(Int(value as? Double ?? 0)) \(unit.rawValue)"
        case .format:
            return "\(field.displayName) \(`operator`.displayName) \(value)"
        }
    }
    
    public var requiresIndexing: Bool { false }
    
    // Custom Codable implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        field = try container.decode(Field.self, forKey: .field)
        `operator` = try container.decode(ComparisonOperator.self, forKey: .operator)
        unit = try container.decodeIfPresent(DateUnit.self, forKey: .unit)
        
        if let stringValue = try? container.decode(String.self, forKey: .stringValue) {
            value = stringValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .doubleValue) {
            value = doubleValue
        } else if let dateValue = try? container.decode(Date.self, forKey: .dateValue) {
            value = dateValue
        } else {
            throw DecodingError.dataCorruptedError(forKey: .stringValue, in: container, debugDescription: "No valid value found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(field, forKey: .field)
        try container.encode(`operator`, forKey: .operator)
        try container.encodeIfPresent(unit, forKey: .unit)
        
        if let stringValue = value as? String {
            try container.encode(stringValue, forKey: .stringValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue, forKey: .doubleValue)
        } else if let dateValue = value as? Date {
            try container.encode(dateValue, forKey: .dateValue)
        }
    }
}

// MARK: - Play Statistics Rules

/// Rule for play statistics
public struct PlayStatisticsRule: SmartPlaylistRuleProtocol {
    public enum Field: String, Codable, CaseIterable {
        case playCount, lastPlayed, rating
        
        var displayName: String {
            switch self {
            case .playCount: return "Play Count"
            case .lastPlayed: return "Last Played"
            case .rating: return "Rating"
            }
        }
    }
    
    let field: Field
    let `operator`: ComparisonOperator
    let value: Any
    let unit: DateUnit?
    
    private enum CodingKeys: String, CodingKey {
        case field, `operator`, unit
        case intValue, doubleValue
    }
    
    public init(field: Field, operator: ComparisonOperator, count: Int) {
        self.field = field
        self.operator = `operator`
        self.value = count
        self.unit = nil
    }
    
    public init(field: Field, operator: ComparisonOperator, dateValue: Double, unit: DateUnit) {
        self.field = field
        self.operator = `operator`
        self.value = dateValue
        self.unit = unit
    }
    
    public func evaluate(track: Track) -> Bool {
        switch field {
        case .playCount:
            let playCount = track.playCount ?? 0
            guard let compareValue = value as? Int else { return false }
            
            switch `operator` {
            case .equals: return playCount == compareValue
            case .notEquals: return playCount != compareValue
            case .greaterThan: return playCount > compareValue
            case .lessThan: return playCount < compareValue
            case .greaterThanOrEqual: return playCount >= compareValue
            case .lessThanOrEqual: return playCount <= compareValue
            default: return false
            }
            
        case .lastPlayed:
            guard let compareValue = value as? Double,
                  let unit = unit else { return false }
            
            let calendar = Calendar.current
            let now = Date()
            var dateComponent = DateComponents()
            
            switch unit {
            case .days: dateComponent.day = -Int(compareValue)
            case .weeks: dateComponent.weekOfYear = -Int(compareValue)
            case .months: dateComponent.month = -Int(compareValue)
            case .years: dateComponent.year = -Int(compareValue)
            }
            
            guard let compareDate = calendar.date(byAdding: dateComponent, to: now) else { return false }
            
            if let lastPlayed = track.lastPlayed {
                switch `operator` {
                case .greaterThan: return lastPlayed > compareDate
                case .lessThan: return lastPlayed < compareDate
                case .greaterThanOrEqual: return lastPlayed >= compareDate
                case .lessThanOrEqual: return lastPlayed <= compareDate
                default: return false
                }
            } else {
                // Track never played
                return `operator` == .notEquals
            }
            
        case .rating:
            // Rating functionality would need to be added to Track model
            return false
        }
    }
    
    public var description: String {
        switch field {
        case .playCount:
            return "\(field.displayName) \(`operator`.displayName) \(value)"
        case .lastPlayed:
            guard let unit = unit else { return "\(field.displayName) \(`operator`.displayName) \(value)" }
            return "\(field.displayName) in the last \(Int(value as? Double ?? 0)) \(unit.rawValue)"
        case .rating:
            return "\(field.displayName) \(`operator`.displayName) \(value)"
        }
    }
    
    public var requiresIndexing: Bool { false }
    
    // Custom Codable implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        field = try container.decode(Field.self, forKey: .field)
        `operator` = try container.decode(ComparisonOperator.self, forKey: .operator)
        unit = try container.decodeIfPresent(DateUnit.self, forKey: .unit)
        
        if let intValue = try? container.decode(Int.self, forKey: .intValue) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .doubleValue) {
            value = doubleValue
        } else {
            throw DecodingError.dataCorruptedError(forKey: .intValue, in: container, debugDescription: "No valid value found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(field, forKey: .field)
        try container.encode(`operator`, forKey: .operator)
        try container.encodeIfPresent(unit, forKey: .unit)
        
        if let intValue = value as? Int {
            try container.encode(intValue, forKey: .intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue, forKey: .doubleValue)
        }
    }
}

// MARK: - Combining Rules

/// Logical operators for combining rules
public enum LogicalOperator: String, Codable {
    case and = "and"
    case or = "or"
    case not = "not"
}

/// Combines multiple rules with logical operators
public struct CombinedRule: SmartPlaylistRuleProtocol {
    let `operator`: LogicalOperator
    let rules: [AnySmartPlaylistRule]
    
    public init(operator: LogicalOperator, rules: [any SmartPlaylistRuleProtocol]) {
        self.operator = `operator`
        self.rules = rules.map(AnySmartPlaylistRule.init)
    }
    
    public func evaluate(track: Track) -> Bool {
        switch `operator` {
        case .and:
            return rules.allSatisfy { $0.evaluate(track: track) }
        case .or:
            return rules.contains { $0.evaluate(track: track) }
        case .not:
            return !rules.allSatisfy { $0.evaluate(track: track) }
        }
    }
    
    public var description: String {
        let ruleDescriptions = rules.map { $0.description }
        switch `operator` {
        case .and:
            return "(" + ruleDescriptions.joined(separator: " AND ") + ")"
        case .or:
            return "(" + ruleDescriptions.joined(separator: " OR ") + ")"
        case .not:
            return "NOT (" + ruleDescriptions.joined(separator: " AND ") + ")"
        }
    }
    
    public var requiresIndexing: Bool {
        rules.contains { $0.requiresIndexing }
    }
}

// MARK: - Type Erasure

/// Type-erased wrapper for SmartPlaylistRule
public struct AnySmartPlaylistRule: SmartPlaylistRuleProtocol {
    private let _evaluate: (Track) -> Bool
    private let _description: () -> String
    private let _requiresIndexing: () -> Bool
    private let _encode: (Encoder) throws -> Void
    
    public init<Rule: SmartPlaylistRuleProtocol>(_ rule: Rule) {
        self._evaluate = rule.evaluate
        self._description = { rule.description }
        self._requiresIndexing = { rule.requiresIndexing }
        self._encode = { encoder in
            try rule.encode(to: encoder)
        }
    }
    
    public func evaluate(track: Track) -> Bool {
        _evaluate(track)
    }
    
    public var description: String {
        _description()
    }
    
    public var requiresIndexing: Bool {
        _requiresIndexing()
    }
    
    // Codable implementation
    private enum CodingKeys: String, CodingKey {
        case type, rule
    }
    
    private enum RuleType: String, Codable {
        case stringMetadata, numericMetadata, fileProperty, playStatistics, combined
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RuleType.self, forKey: .type)
        
        switch type {
        case .stringMetadata:
            let rule = try container.decode(StringMetadataRule.self, forKey: .rule)
            self.init(rule)
        case .numericMetadata:
            let rule = try container.decode(NumericMetadataRule.self, forKey: .rule)
            self.init(rule)
        case .fileProperty:
            let rule = try container.decode(FilePropertyRule.self, forKey: .rule)
            self.init(rule)
        case .playStatistics:
            let rule = try container.decode(PlayStatisticsRule.self, forKey: .rule)
            self.init(rule)
        case .combined:
            let rule = try container.decode(CombinedRule.self, forKey: .rule)
            self.init(rule)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}