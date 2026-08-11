import SwiftUI

struct IconPickerView: View {

    let name: String
    @Binding var iconName: String?
    @Environment(\.dismiss) private var dismiss

    private static let icons = [
        "person.fill", "person.2.fill", "person.crop.circle.fill",
        "heart.fill", "star.fill", "flame.fill", "leaf.fill", "pawprint.fill",
        "sun.max.fill", "moon.fill", "cloud.fill", "bolt.fill",
        "gamecontroller.fill", "sportscourt.fill", "figure.run", "bicycle",
        "airplane", "car.fill", "house.fill", "graduationcap.fill",
        "briefcase.fill", "cart.fill", "fork.knife", "cup.and.saucer.fill",
        "gift.fill", "camera.fill", "music.note", "paintpalette.fill",
        "book.fill", "pencil", "globe", "map.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Button {
                            iconName = icon
                            dismiss()
                        } label: {
                            FriendAvatar(name: name, iconName: icon, size: 52)
                                .overlay {
                                    if iconName == icon {
                                        Circle().strokeBorder(.blue, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose an Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    IconPickerView(name: "Testing Friend", iconName: .constant(nil))
}
