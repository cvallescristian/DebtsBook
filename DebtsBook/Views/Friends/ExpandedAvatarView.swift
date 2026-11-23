import SwiftUI
import SwiftData

/// A friend's photo (or icon/initials) enlarged over a blurred background, like tapping a
/// profile picture on Instagram. Tap anywhere or swipe down to close.
struct ExpandedAvatarView: View {

    let friend: Friend
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var dismissProgress: Double {
        min(abs(dragOffset) / 300, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width - 64, 320)

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(1 - dismissProgress * 0.6)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    FriendAvatar(name: friend.name, photoData: friend.photoData, iconName: friend.iconName, size: size)
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                    Text(friend.name)
                        .font(.title2.bold())
                }
                .offset(y: dragOffset)
                .scaleEffect(1 - dismissProgress * 0.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = max(value.translation.height, 0)
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        onDismiss()
                    } else {
                        withAnimation(.spring) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.name)'s photo")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
        .accessibilityHint("Double-tap to close")
    }
}

extension EnvironmentValues {
    /// Set by `expandedAvatar(_:)`: shows a friend's enlarged avatar over the whole screen,
    /// so views pushed inside it (like friend detail) can open it too.
    @Entry var expandFriendAvatar: ((Friend) -> Void)? = nil
}

extension View {
    /// Shows `friend`'s enlarged avatar over this view while it's non-nil.
    func expandedAvatar(_ friend: Binding<Friend?>) -> some View {
        environment(\.expandFriendAvatar) { friend.wrappedValue = $0 }
        .overlay {
            if let shown = friend.wrappedValue {
                ExpandedAvatarView(friend: shown) {
                    friend.wrappedValue = nil
                }
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: friend.wrappedValue?.persistentModelID)
    }
}
