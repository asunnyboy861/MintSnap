import SwiftUI
import SafariServices

struct CertVerifyView: View {
    let grader: String
    let certNumber: String
    var onVerified: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var safariURL: URL?
    @State private var verified = false

    private var lookupURL: URL? {
        let cert = certNumber.trimmingCharacters(in: .whitespaces)
        switch grader.uppercased() {
        case let g where g.contains("PSA"):
            return URL(string: "https://www.psacard.com/cert/\(cert)")
        case let g where g.contains("BGS") || g.contains("BECKETT"):
            return URL(string: "https://www.beckett.com/grading/card-lookup/?query=\(cert)")
        case let g where g.contains("CGC"):
            return URL(string: "https://www.cgccards.com/certlookup/\(cert)/")
        case let g where g.contains("SGC"):
            return URL(string: "https://www.gosgc.com/cert-verification/\(cert)")
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.mintAccent)

                VStack(spacing: 6) {
                    Text(grader.isEmpty ? "Unknown Grader" : grader)
                        .font(.title2.bold())
                    Text("Cert #\(certNumber)")
                        .font(.title3.monospaced())
                        .foregroundStyle(.secondary)
                }

                if let url = lookupURL {
                    Button {
                        safariURL = url
                    } label: {
                        Label("Open Official Lookup", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("This grader is not supported for cert verification yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if verified {
                    Label("Cert Verified", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color.mintAccent)
                }

                HStack(spacing: 12) {
                    Button {
                        verified = true
                        onVerified?()
                    } label: {
                        Text("Match").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(verified)

                    Button {
                        dismiss()
                    } label: {
                        Text("No Match").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Text("Verifying opens the official grader website. Your data stays on device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Verify Cert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { safariURL.map(SafariAnchor.init) },
                set: { safariURL = $0?.url }
            )) { anchor in
                SafariView(url: anchor.url)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct SafariAnchor: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
