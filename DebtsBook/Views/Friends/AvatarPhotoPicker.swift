import SwiftUI
import PhotosUI

struct AvatarPhotoPicker: View {

    let name: String
    @Binding var photoData: Data?
    @Binding var iconName: String?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingIconPicker = false
    @State private var showingPhotoPicker = false

    var body: some View {
        Menu {
            Button {
                showingPhotoPicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo")
            }
            Button {
                showingIconPicker = true
            } label: {
                Label("Choose Icon", systemImage: "face.smiling")
            }
            if photoData != nil || iconName != nil {
                Button(role: .destructive) {
                    photoData = nil
                    iconName = nil
                    selectedItem = nil
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                FriendAvatar(name: name, photoData: photoData, iconName: iconName, size: 80)

                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white, .blue)
                    .background(Circle().fill(.white))
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(name: name, iconName: $iconName)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = resized(data, maxDimension: 300)
                    iconName = nil
                }
            }
        }
        .onChange(of: iconName) { _, newValue in
            if newValue != nil {
                photoData = nil
                selectedItem = nil
            }
        }
    }

    private func resized(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    AvatarPhotoPicker(name: "Testing Friend", photoData: .constant(nil), iconName: .constant(nil))
}
