import SwiftUI

struct ConnectionSetupView: View {
    @Environment(SupacodeConnection.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var tokenText = ""
    @State private var showScanner = false
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            Form {
                if let saved = ConnectionStore.load() {
                    savedSection(saved)
                }
                manualSection
                qrSection
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                scannerSheet
            }
        }
    }

    // MARK: - Saved Connection

    private func savedSection(_ saved: Connection) -> some View {
        Section("Saved Connection") {
            LabeledContent("Host", value: saved.url.host() ?? saved.url.absoluteString)
            Button("Connect") {
                connect(with: saved)
            }
            Button("Forget", role: .destructive) {
                ConnectionStore.clear()
            }
        }
    }

    // MARK: - Manual Entry

    private var manualSection: some View {
        Section("Manual") {
            TextField("URL (e.g. http://192.168.1.10:7742)", text: $urlText)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Token", text: $tokenText)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Connect") {
                guard let url = URL(string: urlText), !tokenText.isEmpty else { return }
                connect(with: Connection(url: url, token: tokenText))
            }
            .disabled(urlText.isEmpty || tokenText.isEmpty)
        }
    }

    // MARK: - QR Code

    private var qrSection: some View {
        Section {
            if QRScannerView.isSupported {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                }
            } else {
                Label("Camera not available", systemImage: "camera.fill")
                    .foregroundStyle(.secondary)
            }
            if let scanError {
                Text(scanError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } footer: {
            Text("Open Supacode → Settings → Web Access on your Mac to show the QR code.")
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { scanned in
                showScanner = false
                handleScannedURL(scanned)
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showScanner = false }
                }
            }
        }
    }

    // MARK: - Logic

    private func handleScannedURL(_ raw: String) {
        guard let components = URLComponents(string: raw),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else {
            scanError = "Invalid QR code — expected a Supacode connection URL"
            return
        }
        var base = components
        base.queryItems = nil
        guard let url = base.url else {
            scanError = "Could not parse URL from QR code"
            return
        }
        scanError = nil
        urlText = url.absoluteString
        tokenText = token
        connect(with: Connection(url: url, token: token))
    }

    private func connect(with newConnection: Connection) {
        ConnectionStore.save(newConnection)
        connection.connection = newConnection
        dismiss()
    }
}
