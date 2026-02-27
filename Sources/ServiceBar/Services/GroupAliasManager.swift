import SwiftUI

enum GroupTag: String, CaseIterable {
    case auto = "AUTO"
    case dev = "DEV"
    case sys = "SYS"
    case app = "APP"
    case db = "DB"
    case web = "WEB"
    case none = ""

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .none: return "None"
        default: return rawValue
        }
    }

    var color: Color {
        switch self {
        case .dev: return .orange
        case .sys: return .blue
        case .app: return .green
        case .db: return .purple
        case .web: return .red
        case .auto, .none: return .clear
        }
    }
}

final class GroupAliasManager: ObservableObject {
    static let shared = GroupAliasManager()

    private let aliasKey = "GroupAliases"
    private let tagKey = "GroupTags"
    @Published private(set) var aliases: [String: String]
    @Published private(set) var tags: [String: String] // originalName -> GroupTag rawValue

    private init() {
        aliases = UserDefaults.standard.dictionary(forKey: aliasKey) as? [String: String] ?? [:]
        tags = UserDefaults.standard.dictionary(forKey: tagKey) as? [String: String] ?? [:]
    }

    func displayName(for original: String) -> String {
        aliases[original] ?? original
    }

    func setAlias(_ alias: String, for original: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == original {
            aliases.removeValue(forKey: original)
        } else {
            aliases[original] = trimmed
        }
        UserDefaults.standard.set(aliases, forKey: aliasKey)
    }

    func tag(for original: String, autoIsDev: Bool) -> GroupTag {
        if let raw = tags[original], let t = GroupTag(rawValue: raw) {
            return t
        }
        // Auto: no override stored
        return autoIsDev ? .dev : .none
    }

    func setTag(_ tag: GroupTag, for original: String) {
        if tag == .auto {
            tags.removeValue(forKey: original)
        } else {
            tags[original] = tag.rawValue
        }
        UserDefaults.standard.set(tags, forKey: tagKey)
    }

    /// Whether the user has set an explicit tag (non-auto)
    func hasCustomTag(for original: String) -> Bool {
        tags[original] != nil
    }
}
