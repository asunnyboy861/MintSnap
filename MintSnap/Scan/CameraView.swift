import SwiftUI
import AVFoundation

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isFrameLocked = false
    @Published var isCameraAvailable = true
    @Published var authorizationDenied = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var onCapture: ((CGImage) -> Void)?
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    func configure() {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            isCameraAvailable = false
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.authorizationDenied = true
                        self?.isCameraAvailable = false
                    }
                }
            }
        default:
            authorizationDenied = true
            isCameraAvailable = false
        }
    }

    private func setupSession() {
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            isCameraAvailable = false
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func capture(onSuccess: @escaping (CGImage) -> Void) {
        guard isCameraAvailable else { return }
        hapticMedium.impactOccurred()
        onCapture = onSuccess
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let cgImage = photo.cgImageRepresentation() else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(cgImage)
            self?.onCapture = nil
        }
    }

    func stop() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let controller: CameraController

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let preview = CameraPreviewView(session: controller.session)
        preview.videoPreviewLayer.videoGravity = .resizeAspectFill
        preview.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: vc.view.topAnchor),
            preview.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        videoPreviewLayer.session = session
        accessibilityLabel = "Camera preview"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
