import SwiftUI
import Network
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.developerModeStorageKey) private var developerModeEnabled = false
    @AppStorage("3105.airlift.use_airlift_all") private var useAirLiftAll = false

    @StateObject private var airLiftPairing = AirLiftPairingController.shared
    @State private var isImportingPairing = false
    @State private var isTestingConnection = false
    @State private var isTunnelConnected = false
    @State private var activeAlert: SettingsAlertItem?

    private enum SettingsAlertItem: Identifiable {
        case testSuccess
        case testFailed
        case removePairingConfirm
        case message(String)

        var id: String {
            switch self {
            case .testSuccess: return "testSuccess"
            case .testFailed: return "testFailed"
            case .removePairingConfirm: return "removePairingConfirm"
            case .message(let msg): return "msg_\(msg)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Logo & App Info
                Section {
                    HStack(spacing: 14) {
                        AppLogo()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("3105").font(.headline)
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Section 2: Language
                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Section 3: Features
                Section {
                    Toggle(isOn: $cleanerEnabled) {
                        Label(language.text("tab.cleaner"), systemImage: "sparkles")
                    }
                    Toggle(isOn: $developerModeEnabled) {
                        Label(
                            language.text("settings.developer_mode"),
                            systemImage: "hammer.fill"
                        )
                    }
                } header: {
                    Text(language.text("dashboard.features"))
                } footer: {
                    Text(language.text("settings.developer_mode_footer"))
                }

                // Section 4: Wallpaper Reset (if supported)
                if WallpaperFeatureSupportPolicy.isSupported(
                    major: AppInfo.versionTuple.major
                ) {
                    Section {
                        NavigationLink {
                            WallpaperResetSettingsView()
                        } label: {
                            Label(
                                language.text("wallpaper.reset"),
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                    } header: {
                        Text(language.text("tab.wallpapers"))
                    } footer: {
                        Text(language.text("wallpaper.reset_settings_footer"))
                    }
                }

                // Section 5: AirLift Connection & On-Device Pairing
                Section {
                    // Status Rows
                    connectionStatusRow(
                        titleKey: "public_settings.tunnel",
                        valueKey: isTunnelConnected ? "public_settings.connected" : "public_settings.disconnected",
                        ready: isTunnelConnected
                    )

                    connectionStatusRow(
                        titleKey: "public_settings.pairing",
                        valueKey: AirLiftPairingStore.shared.hasRecord ? "airlift.ready" : "airlift.not_configured",
                        ready: AirLiftPairingStore.shared.hasRecord
                    )

                    // On-Device Pairing Button & PIN Presentation
                    if airLiftPairing.isRunning {
                        VStack(spacing: 12) {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text(airLiftPairing.pairingStatus)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            if let pin = airLiftPairing.pairingPIN {
                                VStack(spacing: 6) {
                                    Text(language.text("airlift.pin"))
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(pin)
                                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                    Text(language.text("public_settings.pairing_guide"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }

                            Button(action: {
                                airLiftPairing.cancelPairing()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text(language.text("airlift.cancel_pairing"))
                                }
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(action: {
                            airLiftPairing.startOnDevicePairing()
                        }) {
                            HStack {
                                Image(systemName: "iphone.badge.play")
                                Text(language.text("airlift.pair_on_device"))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // Import and Remove pairing
                    Button(action: {
                        isImportingPairing = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(language.text("airlift.import"))
                        }
                    }

                    if AirLiftPairingStore.shared.hasRecord {
                        Button(role: .destructive, action: {
                            activeAlert = .removePairingConfirm
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text(language.text("airlift.remove"))
                            }
                        }
                    }

                    // Test AirLift Connection
                    Button(action: testAirLiftConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "checkmark.shield")
                            }
                            Text(language.text("airlift.test_connection"))
                        }
                    }
                    .disabled(isTestingConnection)

                    // Navigation to full Diagnostics
                    NavigationLink {
                        AirLiftDiagnosticsView()
                    } label: {
                        Label(language.text("airlift.diagnostics.title"), systemImage: "stethoscope")
                    }

                    // Navigation to Setup Guide
                    NavigationLink {
                        AirLiftFirstRunSetupView()
                    } label: {
                        Label(language.text("airlift.first_run.connection_title"), systemImage: "network")
                    }

                    // Global AirLift Override Toggle
                    Toggle(isOn: $useAirLiftAll) {
                        Text(language.text("public_settings.use_airlift_all"))
                    }
                    .onChange(of: useAirLiftAll) { val in
                        appState.detectSupport()
                    }
                } header: {
                    Text(language.text("public_settings.connection"))
                } footer: {
                    Text(language.text("public_settings.pairing_footer"))
                }

                // Section 6: Dialer / Passcode Capture
                Section(language.text("public_settings.capture_dialer_passcode")) {
                    HStack {
                        Image(systemName: "phone.badge.waveform.fill")
                            .foregroundColor(AppTheme.accent)
                        Text(language.text("public_settings.capture_dialer_passcode"))
                        Spacer()
                    }
                }

                // Section 7: Device Information
                Section(language.text("common.device")) {
                    LabeledContent(language.text("dashboard.hardware_model"), value: AppInfo.displayMachineName)
                    LabeledContent(language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                }

                // Section 8: Supported Versions
                Section {
                    HStack {
                        Text(language.text("settings.current_version"))
                        Spacer()
                        Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                            .foregroundStyle(appState.isSupported ? Color.green : Color.red)
                    }
                    LabeledContent("iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
                    LabeledContent("iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
                    LabeledContent("iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iOS 27.0")
                            .font(.body)
                        ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                            Text(versionLabel(version))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(language.text("settings.verified_versions"))
                } footer: {
                    Text(language.text("settings.supported_versions_footer"))
                }

                // Section 9: Social Media & Credits
                Section(language.text("settings.social_media")) {
                    creditsRow(
                        name: "GitHub",
                        role: language.text("social.github_role"),
                        url: "https://github.com/YangJiiii/3105"
                    )
                    creditsRow(
                        name: "Cộng Đồng IOSVN",
                        role: language.text("social.iosvn_role"),
                        url: "https://t.me/ioscrackvn"
                    )
                }

                Section(language.text("settings.credits")) {
                    creditsRow(
                        name: "YangJiii",
                        role: language.text("credit.yangjiii"),
                        url: "https://x.com/duongduong0908"
                    )
                    creditsRow(
                        name: "0xjohnnydev",
                        role: language.text("credit.filzaslop"),
                        url: "https://github.com/0xjohnnydev/FilzaSlop"
                    )
                    creditsRow(
                        name: "LeminLimez",
                        role: language.text("credit.pocket_poster"),
                        url: "https://github.com/leminlimez/Pocket-Poster"
                    )
                    creditsRow(
                        name: "CrazyMind90",
                        role: language.text("credit.sandbox_escape"),
                        url: "https://github.com/CrazyMind90"
                    )
                    creditsRow(
                        name: "forcequitOS",
                        role: language.text("credit.forcequit"),
                        url: "https://github.com/forcequitOS"
                    )
                }
            }
            .tint(AppTheme.accent)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .fileImporter(
                isPresented: $isImportingPairing,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let ok = airLiftPairing.importPairingFile(from: url)
                        if ok {
                            activeAlert = .message(language.text("airlift.import_success_message"))
                        } else {
                            activeAlert = .message(airLiftPairing.lastError ?? "Import failed")
                        }
                    }
                case .failure(let err):
                    activeAlert = .message(err.localizedDescription)
                }
            }
            .alert(item: $activeAlert) { item in
                switch item {
                case .testSuccess:
                    return Alert(
                        title: Text(language.text("airlift.test_success_title")),
                        message: Text(language.text("airlift.test_success_message")),
                        dismissButton: .default(Text("OK"))
                    )
                case .testFailed:
                    return Alert(
                        title: Text(language.text("airlift.test_failed_title")),
                        message: Text("Không thể kết nối cổng RSD (49152) qua 10.7.0.1. Vui lòng bật LocalDevVPN và đảm bảo có Wi-Fi."),
                        dismissButton: .default(Text("OK"))
                    )
                case .removePairingConfirm:
                    return Alert(
                        title: Text(language.text("airlift.remove")),
                        message: Text("Bạn có chắc chắn muốn xoá file pairing AirLift?"),
                        primaryButton: .destructive(Text(language.text("common.delete"))) {
                            try? AirLiftPairingStore.shared.removeRecord()
                        },
                        secondaryButton: .cancel(Text(language.text("common.cancel")))
                    )
                case .message(let text):
                    return Alert(
                        title: Text("AirLift"),
                        message: Text(text),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .onAppear {
                probeTunnel()
            }
        }
    }

    private func connectionStatusRow(titleKey: String, valueKey: String, ready: Bool) -> some View {
        HStack {
            Text(language.text(titleKey))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(ready ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(language.text(valueKey))
                    .foregroundColor(ready ? .green : .secondary)
            }
        }
    }

    private func probeTunnel() {
        Task {
            let endpoint = NWEndpoint.hostPort(host: "10.7.0.1", port: 49152)
            let conn = NWConnection(to: endpoint, using: .tcp)
            var done = false
            conn.stateUpdateHandler = { st in
                guard !done else { return }
                if case .ready = st {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTunnelConnected = true
                    }
                } else if case .failed = st {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTunnelConnected = false
                    }
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if !done {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTunnelConnected = false
                    }
                }
            }
        }
    }

    private func testAirLiftConnection() {
        isTestingConnection = true
        Task {
            let endpoint = NWEndpoint.hostPort(host: "10.7.0.1", port: 49152)
            let conn = NWConnection(to: endpoint, using: .tcp)
            var done = false
            conn.stateUpdateHandler = { st in
                guard !done else { return }
                if case .ready = st {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTestingConnection = false
                        self.isTunnelConnected = true
                        self.activeAlert = .testSuccess
                    }
                } else if case .failed = st {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTestingConnection = false
                        self.isTunnelConnected = false
                        self.activeAlert = .testFailed
                    }
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if !done {
                    done = true
                    conn.cancel()
                    Task { @MainActor in
                        self.isTestingConnection = false
                        self.isTunnelConnected = false
                        self.activeAlert = .testFailed
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.1 Beta 2 Offline v2"
    }

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
        if let publicBeta = version.publicBeta {
            return language.text(
                "settings.developer_public_beta_build",
                Int64(version.beta),
                Int64(publicBeta),
                version.build
            )
        }
        return language.text(
            "settings.developer_beta_build",
            Int64(version.beta),
            version.build
        )
    }

    @ViewBuilder
    private func creditsRow(name: String, role: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(language.text("accessibility.open_profile", name))
        }
    }
}
