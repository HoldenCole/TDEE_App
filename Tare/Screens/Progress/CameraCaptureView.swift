import SwiftUI
import AVFoundation
import PhotosUI
import SwiftData
import TareEngine

/// In-app camera with a faded overlay of the last photo in the same pose, and a 3-second timer.
struct CameraCaptureView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var pose: PhotoPose
    @State private var customName = ""
    @State private var timerOn = true
    @State private var countdown: Int? = nil
    @State private var controller = CameraController()
    @State private var captured: UIImage?
    @State private var frontCamera = false

    init(defaultPose: PhotoPose) {
        _pose = State(initialValue: defaultPose)
    }

    private var overlay: UIImage? {
        guard let last = photos.first(where: { $0.pose == pose && (pose != .custom || $0.customPoseName == customName) }) else { return nil }
        return UIImage(data: last.thumbnailData ?? last.imageData)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let captured {
                review(captured)
            } else {
                capture
            }
        }
        .onAppear { controller.start(front: frontCamera) }
        .onDisappear { controller.stop() }
    }

    private var capture: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
                }
                Spacer()
                Button {
                    frontCamera.toggle()
                    controller.start(front: frontCamera)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
                }
                Button { timerOn.toggle() } label: {
                    Image(systemName: timerOn ? "timer" : "timer.circle").font(.system(size: 18, weight: .semibold)).foregroundStyle(timerOn ? Color(hex: 0x8FB0FF) : .white).frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)

            ZStack {
                CameraPreview(controller: controller)
                if let overlay {
                    Image(uiImage: overlay).resizable().scaledToFill().opacity(0.35).allowsHitTesting(false)
                }
                if let countdown {
                    Text("\(countdown)").font(.system(size: 120, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipped()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhotoPose.allCases) { p in
                        Button {
                            pose = p
                        } label: {
                            Text(p.title).font(Theme.bodySmall(.semibold))
                                .foregroundStyle(pose == p ? Theme.ink : .white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(pose == p ? Color.white : Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.sideMargin)
            }
            .padding(.top, 16)
            if pose == .custom {
                TextField("Pose name", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Theme.sideMargin).padding(.top, 8)
            }
            Text(overlay == nil ? "First \(pose.title.lowercased()) photo. Stand where you'll stand every time." : "Line yourself up with the faded photo.")
                .font(Theme.caption()).foregroundStyle(.white.opacity(0.7)).padding(.top, 12)
            Spacer()
            Button {
                shoot()
            } label: {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 76, height: 76)
                    .overlay(Circle().fill(.white).frame(width: 62, height: 62))
            }
            .buttonStyle(.plain)
            .disabled(countdown != nil)
            .padding(.bottom, 30)
        }
    }

    private func shoot() {
        guard countdown == nil else { return }
        if timerOn {
            countdown = 3
            Task {
                for i in stride(from: 3, to: 0, by: -1) {
                    countdown = i
                    try? await Task.sleep(for: .seconds(1))
                }
                countdown = nil
                takePhoto()
            }
        } else {
            takePhoto()
        }
    }

    private func takePhoto() {
        controller.capture { image in
            captured = image
        }
    }

    private func review(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, Theme.sideMargin).padding(.top, 20)
            HStack(spacing: 12) {
                PillButton(title: "Retake", tint: .white, background: .white.opacity(0.15)) { captured = nil }
                InkButton(title: "Save", fill: .white, foreground: Theme.ink) {
                    save(image)
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.bottom, 24)
        }
    }

    private func save(_ image: UIImage) {
        PhotoSaver.save(image: image, pose: pose, customName: pose == .custom ? customName : nil, date: Date(), model: model)
    }
}

enum PhotoSaver {
    @MainActor
    static func save(image: UIImage, pose: PhotoPose, customName: String?, date: Date, model: AppModel) {
        let resized = image.resized(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        let thumb = resized.resized(maxDimension: 400).jpegData(compressionQuality: 0.7)
        let dayStart = Calendar.current.startOfDay(for: date)
        let snapshotThatDay = Engine.compute(log: model.log, dials: model.dials, today: date)
        let photo = ProgressPhoto(date: dayStart, pose: pose, customPoseName: customName, imageData: data, thumbnailData: thumb, trendWeightLb: snapshotThatDay.body.trendWeightLb, bodyFatPercent: snapshotThatDay.body.bodyFatPercent, phase: model.dials.phase)
        model.context.insert(photo)
        try? model.context.save()
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - AVFoundation

@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage) -> Void)?
    private let queue = DispatchQueue(label: "tare.camera")

    override init() {
        super.init()
    }

    func start(front: Bool) {
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo
            for input in session.inputs { session.removeInput(input) }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
               let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
            }
            if !session.outputs.contains(output), session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture(_ completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [self] in
            completion?(image)
            completion = nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = controller.session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

// MARK: - Import from the library

struct PhotoImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var date = Date()
    @State private var pose: PhotoPose = .front
    @State private var customName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $item, matching: .images) {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260)
                        } else {
                            Label("Choose a photo", systemImage: "photo.on.rectangle")
                        }
                    }
                }
                Section("Details") {
                    DatePicker("Taken on", selection: $date, in: ...Date(), displayedComponents: .date)
                    Picker("Pose", selection: $pose) {
                        ForEach(PhotoPose.allCases) { Text($0.title).tag($0) }
                    }
                    if pose == .custom { TextField("Pose name", text: $customName) }
                }
                Section {
                    Text("The photo is copied into Tare and tagged with that day's trend weight, body fat and phase. Your library isn't changed.").font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
            }
            .navigationTitle("Import photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let image {
                            PhotoSaver.save(image: image, pose: pose, customName: pose == .custom ? customName : nil, date: date, model: model)
                        }
                        dismiss()
                    }
                    .disabled(image == nil)
                }
            }
            .onChange(of: item) { _, new in
                Task {
                    if let data = try? await new?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        image = img
                    }
                }
            }
        }
    }
}
