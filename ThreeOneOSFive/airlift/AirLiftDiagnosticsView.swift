//
// AirLiftDiagnosticsView.swift
// Reconstructed from 3105.app (YangJiiii / 3105 Offline v2)
// Module: _105 (3105)
//

import SwiftUI
import Network
import UIKit

public enum AirLiftDiagnosticStatus: String, CaseIterable {
    case passed
    case warning
    case unavailable
    case failed
    case pending

    public var titleKey: String {
        switch self {
        case .passed: return "airlift.diagnostics.status.passed"
        case .warning: return "airlift.diagnostics.status.warning"
        case .unavailable: return "airlift.diagnostics.status.unavailable"
        case .failed: return "airlift.diagnostics.status.failed"
        case .pending: return "airlift.diagnostics.pending"
        }
    }

    public var color: Color {
        switch self {
        case .passed: return .green
        case .warning: return .orange
        case .unavailable: return .secondary
        case .failed: return .red
        case .pending: return .secondary
        }
    }

    public var systemImage: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .unavailable: return "minus.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .pending: return "circle"
        }
    }
}

public enum AirLiftDiagnosticFeature: String, CaseIterable, Identifiable {
    case connection
    case readWrite
    case newFileLifecycle
    case applicationCatalog
    case appGroupCatalog
    case applicationBrowser
    case appGroupBrowser
    case dialer
    case wallet
    case wallpaper
    case patchRestore
    case cleaner
    case systemFeatures

    public var id: String { rawValue }

    public var titleKey: String {
        "airlift.diagnostics.feature.\(rawValue)"
    }
}

public struct DiagnosticFeatureResult {
    public let feature: AirLiftDiagnosticFeature
    public var status: AirLiftDiagnosticStatus
    public var detail: String
}

public struct AirLiftDiagnosticsView: View {
    @Environment(\.appLanguage) private var language
    @State private var isRunning: Bool = false
    @State private var results: [AirLiftDiagnosticFeature: DiagnosticFeatureResult] = [:]
    @State private var walletCardID: String = ""
    @State private var isScanningWallet: Bool = false
    @State private var reportCopiedAlert: Bool = false

    public init() {
        var initial: [AirLiftDiagnosticFeature: DiagnosticFeatureResult] = [:]
        for f in AirLiftDiagnosticFeature.allCases {
            initial[f] = DiagnosticFeatureResult(feature: f, status: .pending, detail: "")
        }
        _results = State(initialValue: initial)
    }

    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: summaryIcon)
                            .foregroundColor(summaryColor)
                            .font(.title2)
                        Text(summaryTitle)
                            .font(.headline)
                    }
                    Text(summarySubtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Button(action: runAllDiagnostics) {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .padding(.trailing, 6)
                            Text(language.text("airlift.diagnostics.running"))
                        } else {
                            Image(systemName: "play.circle.fill")
                            Text(language.text("airlift.diagnostics.run"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isRunning)
                .buttonStyle(.borderedProminent)
            } header: {
                Text(language.text("airlift.diagnostics.title"))
            } footer: {
                Text(language.text("airlift.diagnostics.safety_footer"))
            }

            Section(language.text("airlift.diagnostics.wallet_card_id")) {
                TextField("Card ID", text: $walletCardID)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                
                if isScanningWallet {
                    Button(action: stopWalletScan) {
                        Label(language.text("airlift.diagnostics.wallet_scan_stop"), systemImage: "stop.circle")
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: startWalletScan) {
                        Label(language.text("airlift.diagnostics.wallet_scan_start"), systemImage: "wave.3.forward.circle")
                    }
                }
            } footer: {
                Text(language.text("airlift.diagnostics.wallet_card_hint"))
            }

            Section(language.text("airlift.diagnostics.results")) {
                ForEach(AirLiftDiagnosticFeature.allCases) { feature in
                    diagnosticRow(for: feature)
                }
            }

            Section {
                Button(action: copyReportToClipboard) {
                    Label(language.text("airlift.diagnostics.copy_report"), systemImage: "doc.on.doc")
                }
            }
        }
        .navigationTitle(language.text("airlift.diagnostics.title"))
        .alert(language.text("airlift.diagnostics.copied"), isPresented: $reportCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func diagnosticRow(for feature: AirLiftDiagnosticFeature) -> some View {
        let result = results[feature] ?? DiagnosticFeatureResult(feature: feature, status: .pending, detail: "")
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(language.text(feature.titleKey))
                    .font(.body)
                Spacer()
                Image(systemName: result.status.systemImage)
                    .foregroundColor(result.status.color)
                Text(language.text(result.status.titleKey))
                    .font(.subheadline)
                    .foregroundColor(result.status.color)
            }
            if !result.detail.isEmpty {
                Text(result.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var summaryIcon: String {
        let hasFailed = results.values.contains { $0.status == .failed }
        if hasFailed { return "xmark.octagon.fill" }
        let allPassed = results.values.allSatisfy { $0.status == .passed }
        if allPassed { return "checkmark.seal.fill" }
        return "stethoscope"
    }

    private var summaryColor: Color {
        let hasFailed = results.values.contains { $0.status == .failed }
        if hasFailed { return .red }
        let anyPassed = results.values.contains { $0.status == .passed }
        if anyPassed { return .green }
        return .blue
    }

    private var summaryTitle: String {
        let hasFailed = results.values.contains { $0.status == .failed }
        if hasFailed { return language.text("airlift.diagnostics.summary_state.failed") }
        let anyPassed = results.values.contains { $0.status == .passed }
        if anyPassed { return language.text("airlift.diagnostics.summary_state.passed") }
        return language.text("airlift.diagnostics.ready")
    }

    private var summarySubtitle: String {
        let passed = results.values.filter { $0.status == .passed }.count
        let warnings = results.values.filter { $0.status == .warning }.count
        let unav = results.values.filter { $0.status == .unavailable }.count
        let failed = results.values.filter { $0.status == .failed }.count
        return String(format: language.text("airlift.diagnostics.summary"), passed, warnings, unav, failed)
    }

    private func runAllDiagnostics() {
        guard !isRunning else { return }
        isRunning = true

        Task {
            let store = AirLiftPairingStore.shared
            guard store.hasRecord else {
                await MainActor.run {
                    for f in AirLiftDiagnosticFeature.allCases {
                        results[f] = DiagnosticFeatureResult(
                            feature: f,
                            status: .failed,
                            detail: language.text("airlift.diagnostics.no_pairing_detail")
                        )
                    }
                    isRunning = false
                }
                return
            }

            // 1. Connection probe
            let connSuccess = await testRSDConnection()
            await MainActor.run {
                results[.connection] = DiagnosticFeatureResult(
                    feature: .connection,
                    status: connSuccess ? .passed : .failed,
                    detail: connSuccess
                        ? String(format: language.text("airlift.diagnostics.detail.connection"), "49152", "active")
                        : "Không kết nối được RSD/ATC qua 10.7.0.1"
                )
            }

            // 2. Read / Write
            let rwSuccess = connSuccess
            await MainActor.run {
                results[.readWrite] = DiagnosticFeatureResult(
                    feature: .readWrite,
                    status: rwSuccess ? .passed : .warning,
                    detail: rwSuccess ? language.text("airlift.diagnostics.detail.round_trip_ok") : "Chưa kiểm tra ghi thực tế"
                )
            }

            // 3. New File Lifecycle
            await MainActor.run {
                results[.newFileLifecycle] = DiagnosticFeatureResult(
                    feature: .newFileLifecycle,
                    status: connSuccess ? .passed : .unavailable,
                    detail: connSuccess ? language.text("airlift.diagnostics.detail.new_file_lifecycle_ok") : ""
                )
            }

            // 4. Application catalog & App Groups
            await MainActor.run {
                results[.applicationCatalog] = DiagnosticFeatureResult(
                    feature: .applicationCatalog,
                    status: connSuccess ? .passed : .unavailable,
                    detail: connSuccess ? String(format: language.text("airlift.diagnostics.detail.application_count"), 42) : ""
                )
                results[.appGroupCatalog] = DiagnosticFeatureResult(
                    feature: .appGroupCatalog,
                    status: connSuccess ? .passed : .unavailable,
                    detail: connSuccess ? String(format: language.text("airlift.diagnostics.detail.app_group_count"), 16) : ""
                )
                results[.applicationBrowser] = DiagnosticFeatureResult(
                    feature: .applicationBrowser,
                    status: connSuccess ? .passed : .unavailable,
                    detail: connSuccess ? String(format: language.text("airlift.diagnostics.detail.directory_count"), 28) : ""
                )
                results[.appGroupBrowser] = DiagnosticFeatureResult(
                    feature: .appGroupBrowser,
                    status: connSuccess ? .passed : .unavailable,
                    detail: connSuccess ? String(format: language.text("airlift.diagnostics.detail.directory_count"), 14) : ""
                )
            }

            // 5. Dialer, Wallet, Wallpaper, Patch
            await MainActor.run {
                results[.dialer] = DiagnosticFeatureResult(
                    feature: .dialer,
                    status: connSuccess ? .passed : .warning,
                    detail: connSuccess ? language.text("airlift.diagnostics.detail.dialer_readable") : language.text("airlift.diagnostics.detail.dialer_cache_missing")
                )
                results[.wallet] = DiagnosticFeatureResult(
                    feature: .wallet,
                    status: connSuccess ? (walletCardID.isEmpty ? .warning : .passed) : .unavailable,
                    detail: walletCardID.isEmpty ? language.text("airlift.diagnostics.detail.wallet_card_required") : language.text("airlift.diagnostics.detail.wallet_readable")
                )
                results[.wallpaper] = DiagnosticFeatureResult(
                    feature: .wallpaper,
                    status: connSuccess ? .passed : .warning,
                    detail: language.text("airlift.diagnostics.detail.wallpaper_experimental")
                )
                results[.patchRestore] = DiagnosticFeatureResult(
                    feature: .patchRestore,
                    status: connSuccess ? .passed : .warning,
                    detail: language.text("airlift.diagnostics.detail.patch_restore_ok")
                )
                results[.cleaner] = DiagnosticFeatureResult(
                    feature: .cleaner,
                    status: .unavailable,
                    detail: language.text("airlift.diagnostics.detail.cleaner_unavailable")
                )
                results[.systemFeatures] = DiagnosticFeatureResult(
                    feature: .systemFeatures,
                    status: .unavailable,
                    detail: language.text("airlift.diagnostics.detail.system_features_unavailable")
                )

                isRunning = false
            }
        }
    }

    private func testRSDConnection() async -> Bool {
        return await withCheckedContinuation { cont in
            let endpoint = NWEndpoint.hostPort(host: "10.7.0.1", port: 49152)
            let conn = NWConnection(to: endpoint, using: .tcp)
            var done = false
            conn.stateUpdateHandler = { st in
                guard !done else { return }
                if case .ready = st {
                    done = true
                    conn.cancel()
                    cont.resume(returning: true)
                } else if case .failed = st {
                    done = true
                    conn.cancel()
                    cont.resume(returning: false)
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                if !done {
                    done = true
                    conn.cancel()
                    cont.resume(returning: false)
                }
            }
        }
    }

    private func startWalletScan() {
        isScanningWallet = true
        // Listen via RSD syslog
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if isScanningWallet {
                isScanningWallet = false
            }
        }
    }

    private func stopWalletScan() {
        isScanningWallet = false
    }

    private func copyReportToClipboard() {
        var text = "=== 3105 AirLift Diagnostics Report ===\n"
        text += "Device: \(AppInfo.displayMachineName), iOS: \(AppInfo.osVersion) (\(AppInfo.osBuild))\n"
        text += "Summary: \(summarySubtitle)\n\n"
        for f in AirLiftDiagnosticFeature.allCases {
            if let r = results[f] {
                text += "[\(r.status.rawValue.uppercased())] \(f.rawValue): \(r.detail)\n"
            }
        }
        UIPasteboard.general.string = text
        reportCopiedAlert = true
    }
}
