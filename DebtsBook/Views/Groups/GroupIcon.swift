import SwiftUI

struct GroupIcon: View {
    let name: String
    let iconName: String?
    let color: Color
    var size: CGFloat = 32

    init(group: ExpenseGroup, size: CGFloat = 32) {
        self.name = group.name
        self.iconName = group.iconName
        self.color = group.displayColor
        self.size = size
    }

    init(name: String, iconName: String?, color: Color, size: CGFloat = 32) {
        self.name = name
        self.iconName = iconName
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color.opacity(0.18))
            .overlay {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: size * 0.45, weight: .semibold))
                } else {
                    Text(name.first.map { String($0).uppercased() } ?? "?")
                        .font(.system(size: size * 0.45, weight: .semibold))
                }
            }
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Colour and icon sections for the new/edit group forms.
struct GroupStyleSections: View {
    let name: String
    @Binding var colorName: String?
    @Binding var iconName: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var color: Color {
        GroupStyle.color(named: colorName) ?? .blue
    }

    var body: some View {
        Section("Colour") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GroupStyle.colorNames, id: \.self) { name in
                    Button {
                        colorName = name
                    } label: {
                        Circle()
                            .fill(GroupStyle.color(named: name) ?? .blue)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if colorName == name {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name.capitalized)
                    .accessibilityAddTraits(colorName == name ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }

        Section("Icon") {
            LazyVGrid(columns: columns, spacing: 12) {
                iconTile(nil)
                ForEach(GroupStyle.iconNames, id: \.self) { icon in
                    iconTile(icon)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// `nil` is the "no icon" tile, which shows the group's initial.
    private func iconTile(_ icon: String?) -> some View {
        Button {
            iconName = icon
        } label: {
            GroupIcon(name: name.isEmpty ? "?" : name, iconName: icon, color: color, size: 40)
                .overlay {
                    if iconName == icon {
                        Circle().strokeBorder(color, lineWidth: 2)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon ?? "No Icon")
        .accessibilityAddTraits(iconName == icon ? .isSelected : [])
    }
}

/// Large preview shown at the top of the new/edit group forms.
struct GroupStylePreview: View {
    let name: String
    let colorName: String?
    let iconName: String?

    var body: some View {
        HStack {
            Spacer()
            GroupIcon(name: name.isEmpty ? "?" : name, iconName: iconName, color: GroupStyle.color(named: colorName) ?? .blue, size: 72)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}
