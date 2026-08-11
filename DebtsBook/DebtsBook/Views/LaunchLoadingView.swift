import SwiftUI

struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            ProgressView()
        }
    }
}

#Preview {
    LaunchLoadingView()
}
