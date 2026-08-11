import SwiftUI

private struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

extension View {
    func authFieldStyle() -> some View {
        modifier(InputFieldStyle())
    }
}
