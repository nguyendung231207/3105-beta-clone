//
// AirLiftPairingController.swift
// Ported from 3105 & AirCard-iOS to PROXYDECK (App)
//

import Foundation
import Combine
import AVFAudio
import Network
import UserNotifications
import UIKit

// MARK: - Keep-alive Audio Engine
/// Keeps the app alive in the background while the user switches to Settings > Developer Mode
@MainActor
public final class AirLiftKeepAlive: NSObject {
    public static let shared = AirLiftKeepAlive()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isAudioRunning = false

    func startAudio() {
        guard !isAudioRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if player.engine == nil {
                engine.attach(player)
            }
            let format = engine.outputNode.inputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                isAudioRunning = true
                return
            }

            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = max(1024, AVAudioFrameCount(format.sampleRate))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                isAudioRunning = true
                return
            }
            buffer.frameLength = frames
            if let channelData = buffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memset(channelData[ch], 0, Int(frames) * MemoryLayout<Float>.size)
                }
            }

            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            isAudioRunning = true
        } catch {
            isAudioRunning = false
        }
    }

    func stopAudio() {
        guard isAudioRunning else { return }
        isAudioRunning = false
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        if player.engine != nil {
            engine.detach(player)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

// MARK: - Local Network Authorization
/// Triggers the Local Network permission dialog on iOS 14+ via Bonjour probe
@MainActor
final class AirLiftLocalNetworkAuth {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?
    private let probeType = "_aircardprobe._tcp"

    func request(timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "AirLiftProbe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.browser = browser

            listener?.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated { self?.finish(true) }
            }
        }
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}

// MARK: - AirLift Pairing Controller
@MainActor
public final class AirLiftPairingController: ObservableObject {
    public static let shared = AirLiftPairingController()

    @Published public private(set) var isRunning: Bool = false
    @Published public var pairingStatus: String = "idle"
    @Published public var pairingPIN: String? = nil
    @Published public var lastError: String? = nil
    @Published public var discoveredPairingFiles: [URL] = []

    private var currentSession: PairingSession?
    private var netService: NetService?
    private let keepAlive = AirLiftKeepAlive()
    private let localNetworkAuth = AirLiftLocalNetworkAuth()

    private let hostName = "3105"
    private let hostModel = "Mac17,7"

    public init() {
        requestNotificationPermission()
        scanForExistingPairingFiles()
    }

    public func startOnDevicePairing(store: AirLiftPairingStore = .shared) {
        guard !isRunning else { return }
        isRunning = true
        pairingPIN = nil
        lastError = nil
        pairingStatus = "Khởi tạo host ghép đôi..."

        Task {
            _ = await localNetworkAuth.request()
            guard isRunning else { return }

            // Start silent background audio keep-alive
            keepAlive.startAudio()
            pairingStatus = "Đang phát sóng... Vui lòng mở Cài đặt để ghép đôi"

            let outputPath = store.canonicalPairingFilePath()

            currentSession = PairingGlue.startPairing(
                withName: hostName,
                model: hostModel,
                outputPath: outputPath,
                readyBlock: { [weak self] serviceID, port, txtRecord in
                    DispatchQueue.main.async {
                        self?.pairingStatus = "Đang quảng bá Bonjour (_remotepairing)..."
                        self?.advertiseBonjourService(serviceID: serviceID, port: port, txtRecord: txtRecord)
                    }
                },
                pinBlock: { [weak self] pin in
                    DispatchQueue.main.async {
                        self?.pairingPIN = pin
                        self?.pairingStatus = "Nhập mã PIN \(pin) trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ Nhà phát triển"
                        self?.postPINNotification(pin: pin)
                    }
                },
                completion: { [weak self] success, filePath, error in
                    DispatchQueue.main.async {
                        self?.isRunning = false
                        self?.stopAdvertising()
                        
                        // Keep audio alive for 5 seconds so process doesn't terminate before user switches back
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                            self?.keepAlive.stopAudio()
                        }

                        if success, let path = filePath {
                            self?.pairingStatus = "Đã ghép đôi thành công!"
                            store.setActivePairing(path: path)
                        } else {
                            self?.pairingStatus = "Ghép đôi thất bại"
                            self?.lastError = error?.localizedDescription ?? "Handshake failed"
                        }
                    }
                }
            )
        }
    }

    public func cancelPairing() {
        currentSession?.cancel()
        currentSession = nil
        stopAdvertising()
        keepAlive.stopAudio()
        isRunning = false
        pairingPIN = nil
        pairingStatus = "Đã huỷ"
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    private func advertiseBonjourService(serviceID: String, port: UInt16, txtRecord: [AnyHashable: Any]) {
        stopAdvertising()
        let service = NetService(
            domain: "local.",
            type: "_remotepairing-pairable-host._tcp.",
            name: hostName,
            port: Int32(port)
        )

        var dict: [String: Data] = [:]
        for (key, val) in txtRecord {
            guard let keyStr = key as? String else { continue }
            if let d = val as? Data {
                dict[keyStr] = d
            } else if let s = val as? String, let d = s.data(using: .utf8) {
                dict[keyStr] = d
            }
        }
        if let data = NetService.data(fromTXTRecord: dict) {
            service.setTXTRecord(data)
        }
        service.publish()
        self.netService = service
    }

    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func postPINNotification(pin: String) {
        let content = UNMutableNotificationContent()
        content.title = "AirLift"
        content.body = "Pairing PIN: \(pin)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "proxydeck-pairing-pin",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Auto-discovery & File Import
    public func scanForExistingPairingFiles() {
        var found: [URL] = []
        let fm = FileManager.default

        // 1. App Documents
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let items = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
                for item in items where isPairingExtension(item) {
                    found.append(item)
                }
            }
        }

        // 2. Known SideStore / LiveContainer canonical paths if accessible
        let searchRoots = [
            "/var/mobile/Containers/Shared/AppGroup",
            "/var/mobile/Library/LiveContainer",
            "/var/mobile/Documents/SideStore"
        ]
        for root in searchRoots {
            let u = URL(fileURLWithPath: root)
            if let enumerator = fm.enumerator(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.contains("Pairing") || isPairingExtension(fileURL) {
                        found.append(fileURL)
                    }
                }
            }
        }

        self.discoveredPairingFiles = found
    }

    public func importPairingFile(from sourceURL: URL, store: AirLiftPairingStore = .shared) -> Bool {
        do {
            let shouldStop = sourceURL.startAccessingSecurityScopedResource()
            defer { if shouldStop { sourceURL.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: sourceURL)
            guard !data.isEmpty else { return false }

            try store.importRecord(data)
            self.pairingStatus = "Đã nạp file pairing: \(sourceURL.lastPathComponent)"
            return true
        } catch {
            self.lastError = "Lỗi nạp file: \(error.localizedDescription)"
            return false
        }
    }

    private func isPairingExtension(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        return ext == "mobiledevicepairing" || ext == "mobilepair" || (ext == "plist" && name.contains("pair"))
    }
}
