import PhotosUI
import SwiftUI

/// SCR-05 촬영·업로드 (FR-CAP-02, 03). 사전 검증·변환은 ImageProcessor.
struct CaptureView: View {
    @Environment(CaptureFlowModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsCamera = false

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("얼굴 사진을 준비해 주세요.")
                .appText(.heading4)
                .foregroundStyle(.ink)

            if let reason = model.retakeReason {
                NoticeBanner(message: reason)
            }
            if !model.aiAvailable {
                NoticeBanner(message: AppCopy.serverMaintenance)
            }

            preview

            if let error = model.imageError {
                Text(error)
                    .appText(.bodySmall)
                    .foregroundStyle(.gradeCare)
            }

            HStack(spacing: Spacing.sm) {
                if cameraAvailable {
                    Button(model.image == nil ? "촬영하기" : "다시 찍기") { showsCamera = true }
                        .buttonStyle(.outline)
                }
                let albumTitle = model.image == nil ? "앨범에서 선택" : "다른 사진 선택"
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Text(albumTitle)
                }
                .buttonStyle(.outline)
            }

            Button("다음") { model.path.append(.survey) }
                .buttonStyle(.primary)
                .disabled(model.image == nil || !model.aiAvailable)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.md)
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .captureCloseButton()
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.handlePickedImage(data)
                } else {
                    model.handleImageLoadFailure()
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in
                Task { await model.handlePickedImage(data) }
            }
            .ignoresSafeArea()
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.canvasSoft)
            if let image = model.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityLabel("선택한 얼굴 사진 미리보기")
            } else if model.isProcessingImage {
                ProgressView().tint(.ink)
            } else {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.textFaint)
                    Text("정면 얼굴 사진 1장")
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 전면 카메라 촬영. TODO: 얼굴 가이드 오버레이가 있는 AVFoundation 커스텀 카메라로 교체 (패치 §2 SCR-05)
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // 사진 앱에 저장하지 않는다 (NFR-PRI-01). 메모리에서만 넘긴다.
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 1) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
