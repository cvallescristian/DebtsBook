import SwiftUI
import UIKit

struct FriendRow: View {

    let friend: Friend
    let balance: Decimal

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(name: friend.name, photoData: friend.photoData, iconName: friend.iconName)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if friend.linkedUserID != nil {
                    Label("Connected", systemImage: "link.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else if friend.connectionID != nil {
                    Label("Invite Pending", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 8)

            if balance == 0 {
                Label("Settled up", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            } else {
                Text(balance, format: .currency(code: "NZD").sign(strategy: .always()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(balance > 0 ? .green : .red)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
    }
}

struct FriendAvatar: View {
    let name: String
    var photoData: Data? = nil
    var iconName: String? = nil
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var color: Color {
        let hash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let palette: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo, .green]
        return palette[hash % palette.count]
    }

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let iconName {
                Circle()
                    .fill(color.opacity(0.15))
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(color)
                    }
            } else {
                Circle()
                    .fill(color.opacity(0.15))
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(color)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    List {
        FriendRow(friend: Friend(name: "Testing Friend"), balance: 42.50)
        FriendRow(friend: Friend(name: "valles.cristian1992@gmail.com"), balance: 0)
        FriendRow(friend: Friend(name: "Jane Doe"), balance: -18)
    }
}
