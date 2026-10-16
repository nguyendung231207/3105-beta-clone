//
// AirLiftFirstRunSetupView.swift
// Decompiled / Reconstructed from 3105.app (YangJiiii / 3105 Offline v2)
// Module: _105 (3105)
//

import SwiftUI
import Network
import UniformTypeIdentifiers

public enum AirLiftFirstRunStep: Int, CaseIterable {
    case wifiAndVPN = 1
    case pairing = 2
    case testConnection = 3
    case ready = 4
}

public struct AirLiftFirstRunSetupView: View {
    @Environment(\.dismiss) private var dismiss

    // Official App Store link embedded in the binary
    private static let localDevVPNURL = URL(string: "https://apps.apple.com/us/app/localdevvpn/id6755608044?l=vi")!

    @StateObject private var pairingController = AirLiftPairingController.shared
    @State private var currentStep: AirLiftFirstRunStep = .wifiAndVPN
    @State private var isTunnelActive: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultSuccess: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isImportingPairing: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Step Indicator
                HStack {
                    Text("Thiết lập lần đầu · Bước \(currentStep.rawValue)/4")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch currentStep {
                        case .wifiAndVPN:
                            step1VPNSetupView
                        case .pairing:
                            step2PairingView
                        case .testConnection:
                            step3TestTunnelView
                        case .ready:
                            step4ReadyView
                        }
                    }
                    .padding()
                }

                Spacer()

                // Navigation Buttons
                HStack {
                    if currentStep != .wifiAndVPN {
                        Button("Quay lại") {
                            if let prev = AirLiftFirstRunStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = prev
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentStep != .ready {
                        Button("Tiếp tục") {
                            if let next = AirLiftFirstRunStep(rawValue: currentStep.rawValue + 1) {
                                currentStep = next
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentStep == .pairing && !AirLiftPairingStore.shared.hasRecord)
                    } else {
                        Button("Hoàn tất") {
                            UserDefaults.standard.set(true, forKey: "3105.airlift.first_run_completed")
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Thiết lập AirLift")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImportingPairing,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        _ = pairingController.importPairingFile(from: url)
                    }
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    private var step1VPNSetupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chuẩn bị kết nối AirLift", systemImage: "network")
                .font(.title2.bold())

            Text("AirLift bắt buộc kết nối Wi-Fi và loopback VPN nội bộ để gửi lệnh qua các cổng dịch vụ RSD/AirTraffic.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Link(destination: Self.localDevVPNURL) {
                HStack {
                    Image(systemName: "arrow.down.app")
                    Text("Tải LocalDevVPN từ App Store")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hướng dẫn:")
                    .font(.headline)
                Text("1. Tải và mở LocalDevVPN")
                Text("2. Cài đặt profile VPN và bật công tắc kết nối (IP 10.7.0.1)")
                Text("3. Đảm bảo iPhone đang kết nối cùng mạng Wi-Fi")
            }
            .font(.footnote)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }

    private var step2PairingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Thiết lập Pairing", systemImage: "link")
                .font(.title2.bold())

            Text("Trên iOS 27 trở lên, bạn có thể ghép đôi trực tiếp trên máy qua Cài đặt:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let pin = pairingController.pairingPIN {
                VStack(spacing: 8) {
                    Text("MÃ PIN GHÉP ĐÔI")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(pin)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    Text("Mở Cài đặt › Quyền riêng tư & Bảo mật › Chế độ Nhà phát triển › Ghép đôi mạng để nhập mã PIN này.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            if pairingController.isRunning {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 6)
                        Text(pairingController.pairingStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    Button("Huỷ pairing") {
                        pairingController.cancelPairing()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                Button(action: {
                    pairingController.startOnDevicePairing()
                }) {
                    HStack {
                        Image(systemName: "iphone.badge.play")
                        Text(AirLiftPairingStore.shared.hasRecord ? "Ghép đôi lại trên iPhone" : "Pair trực tiếp trên iPhone")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            if AirLiftPairingStore.shared.hasRecord {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Đã có pairing record hoạt động.")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }

            Text("Hoặc:")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Nhập file pairing từ máy tính (.plist)") {
                isImportingPairing = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var step3TestTunnelView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Kiểm tra kết nối", systemImage: "checkmark.shield")
                .font(.title2.bold())

            Text("3105 sẽ thăm dò dịch vụ RSD (port 49152), ATC và streaming_zip qua dải IP 10.7.0.1.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if testResultSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Kết nối RSD và dịch vụ AirLift thành công!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            } else if let err = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .cornerRadius(10)
            }

            Button(action: {
                isTestingConnection = true
                errorMessage = nil
                Task {
                    let success = await testTunnelConnection()
                    await MainActor.run {
                        isTestingConnection = false
                        testResultSuccess = success
                        if !success {
                            errorMessage = "Không thể kết nối cổng RSD 49152. Hãy đảm bảo LocalDevVPN đang BẬT và iPhone đang có Wi-Fi."
                        }
                    }
                }
            }) {
                HStack {
                    if isTestingConnection {
                        ProgressView()
                            .padding(.trailing, 6)
                    }
                    Text("Kiểm tra kết nối AirLift")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isTestingConnection)
        }
    }

    private var step4ReadyView: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("AirLift đã sẵn sàng!")
                .font(.title2.bold())

            Text("Mọi thao tác đọc/ghi tệp, nạp patch và quản lý container trên iOS 27 sẽ diễn ra trơn tru qua AirLift.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func testTunnelConnection() async -> Bool {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: "10.7.0.1", port: 49152)
            let connection = NWConnection(to: endpoint, using: .tcp)
            var resumed = false
            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
