import SwiftUI

/// Icon and colour choices for expense groups, plus the defaults a new group gets.
enum GroupStyle {

    static let colorNames = ["blue", "orange", "green", "purple", "pink", "teal", "yellow", "indigo", "red", "mint", "brown", "cyan"]

    static let iconNames = [
        "fork.knife", "cart.fill", "cup.and.saucer.fill", "wineglass.fill",
        "car.fill", "bus.fill", "fuelpump.fill", "airplane",
        "house.fill", "bolt.fill", "wifi", "phone.fill",
        "heart.fill", "cross.case.fill", "pills.fill", "dumbbell.fill",
        "gamecontroller.fill", "film.fill", "music.note", "ticket.fill",
        "bag.fill", "tshirt.fill", "gift.fill", "pawprint.fill",
        "graduationcap.fill", "book.fill", "briefcase.fill", "creditcard.fill",
        "leaf.fill", "sparkles", "star.fill", "tag.fill"
    ]

    static let fallbackIconName = "tag.fill"

    /// Matched against the start of each word in the name, first match wins.
    private static let iconKeywords: [(keywords: [String], icon: String)] = [
        (["subscription", "card"], "creditcard.fill"),
        (["food", "eat", "restaurant", "lunch", "dinner", "breakfast", "takeaway"], "fork.knife"),
        (["grocer", "supermarket", "shopping", "market"], "cart.fill"),
        (["coffee", "cafe", "café"], "cup.and.saucer.fill"),
        (["drink", "bar", "alcohol", "wine", "beer"], "wineglass.fill"),
        (["transport", "car", "uber", "taxi", "parking"], "car.fill"),
        (["bus", "train", "commute"], "bus.fill"),
        (["fuel", "petrol", "gas"], "fuelpump.fill"),
        (["travel", "trip", "holiday", "flight", "vacation"], "airplane"),
        (["home", "house", "rent", "mortgage"], "house.fill"),
        (["bill", "power", "electric", "utilit"], "bolt.fill"),
        (["internet", "wifi"], "wifi"),
        (["phone", "mobile"], "phone.fill"),
        (["health", "doctor", "medical"], "cross.case.fill"),
        (["pharmacy", "medicine"], "pills.fill"),
        (["gym", "fitness", "sport"], "dumbbell.fill"),
        (["game", "gaming"], "gamecontroller.fill"),
        (["fun", "entertainment", "movie", "cinema", "netflix", "streaming"], "film.fill"),
        (["music", "concert", "spotify"], "music.note"),
        (["clothes", "clothing", "fashion"], "tshirt.fill"),
        (["gift", "present"], "gift.fill"),
        (["pet", "dog", "cat", "vet"], "pawprint.fill"),
        (["school", "education", "course", "study"], "graduationcap.fill"),
        (["book"], "book.fill"),
        (["work", "office", "business"], "briefcase.fill"),
    ]

    static func color(named name: String?) -> Color? {
        switch name {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "red": return .red
        case "mint": return .mint
        case "brown": return .brown
        case "cyan": return .cyan
        default: return nil
        }
    }

    /// An icon that matches the group's name, or a generic tag.
    static func defaultIconName(for groupName: String) -> String {
        let words = groupName.lowercased().split { !$0.isLetter }
        for entry in iconKeywords {
            let matches = words.contains { word in entry.keywords.contains { word.hasPrefix($0) } }
            if matches {
                return entry.icon
            }
        }
        return fallbackIconName
    }

    /// The first colour no existing group uses yet, cycling once they're all taken.
    static func nextColorName(existing groups: [ExpenseGroup]) -> String {
        let used = Set(groups.compactMap(\.colorName))
        if let unused = colorNames.first(where: { !used.contains($0) }) {
            return unused
        }
        return colorNames[groups.count % colorNames.count]
    }
}

extension ExpenseGroup {
    /// The chosen colour name, or a stable one derived from the name for groups without one.
    var displayColorName: String {
        if let colorName, GroupStyle.colorNames.contains(colorName) {
            return colorName
        }
        let hash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return GroupStyle.colorNames[hash % GroupStyle.colorNames.count]
    }

    var displayColor: Color {
        GroupStyle.color(named: displayColorName) ?? .blue
    }
}
