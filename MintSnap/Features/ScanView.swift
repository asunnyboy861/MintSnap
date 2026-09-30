import SwiftUI
import SwiftData

struct ScanView: View {
    @Environment(StoreService.self) private var store
    @Environment(QuotaService.self) private var quota
    @State private var viewModel = ScanViewModel()
    @State private var camera = CameraController()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if camera.isCameraAvailable && !camera.authorizationDenied {
                    CameraView(controller: camera)
                        .ignoresSafeArea(edges: .bottom)
                    frameOverlay
                    captureControls
                } else {
                    cameraUnavailableView
                }

                switch viewModel.state {
                case .identifying:
                    identifyingOverlay
                case .confirming(let session):
                    ResultCardView(
                        session: session,
                        cloudNotice: viewModel.cloudNotice,
                        onDismiss: resetFlow
                    )
                    .presentationDetents([.medium, .large])
                case .failed(let message):
                    failureOverlay(message)
                case .idle:
                    EmptyView()
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                    }
                    .accessibilityLabel("Upgrade to Pro")
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                camera.configure()
            }
            .onDisappear {
                camera.stop()
            }
        }
    }

    private var frameOverlay: some View {
        VStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.mintAccent, lineWidth: 2)
                .frame(maxWidth: 340, maxHeight: 480)
                .aspectRatio(0.716, contentMode: .fit)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 60)
        .accessibilityHidden(true)
    }

    private var captureControls: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                if viewModel.showSoftWall {
                    Text("\(quota.freeScansRemaining) of 5 free scans left today")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                }
                Button {
                    camera.capture { cgImage in
                        Task {
                            await viewModel.handleCapturedImage(cgImage)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(Color.mintAccent)
                            .frame(width: 64, height: 64)
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityLabel("Scan card")
                .padding(.bottom, 32)
            }
        }
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: camera.authorizationDenied ? "camera.badge.ellipsis" : "camera.on.rectangle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(camera.authorizationDenied ? "Camera access denied" : "Camera unavailable")
                .font(.title3.bold())
            Text(camera.authorizationDenied
                 ? "Enable camera access in Settings to scan cards."
                 : "Scanning requires a device with a camera.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if camera.authorizationDenied {
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var identifyingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.mintAccent)
            Text("Reading card…")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.4))
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Button("Try Again") {
                resetFlow()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func resetFlow() {
        viewModel.reset()
    }
}
