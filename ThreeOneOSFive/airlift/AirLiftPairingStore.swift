//
// AirLiftPairingStore.swift
// Ported from 3105 to PROXYDECK (App)
//

import Foundation

public struct AirLiftPairingStore {
    public static let shared = AirLiftPairingStore()

    public var rootURL: URL?

    public init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    public var hasRecord: Bool {
        if Self.isPairingRevoked { return false }
        guard let path = activePairingPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    public var hasRecordOnDisk: Bool {
        guard let path = activePairingPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    public static var isPairingRevoked: Bool {
        get { UserDefaults.standard.bool(forKey: "3105.airlift.pairing_revoked") }
        set { UserDefaults.standard.set(newValue, forKey: "3105.airlift.pairing_revoked") }
    }

    public static var lastRevocationReason: String? {
        get { UserDefaults.standard.string(forKey: "3105.airlift.revocation_reason") }
        set { UserDefaults.standard.set(newValue, forKey: "3105.airlift.revocation_reason") }
    }

    public static func markPairingRevoked(reason: String? = nil) {
        isPairingRevoked = true
        if let reason = reason {
            lastRevocationReason = reason
        }
    }

    public static func clearPairingRevocation() {
        isPairingRevoked = false
        lastRevocationReason = nil
    }

    public var activePairingPath: String? {
        if let custom = UserDefaults.standard.string(forKey: "3105.airlift.customPairingPath"),
           FileManager.default.fileExists(atPath: custom) {
            return custom
        }
        let canonical = canonicalPairingFilePath()
        if FileManager.default.fileExists(atPath: canonical) {
            return canonical
        }
        return nil
    }

    public func canonicalPairingFilePath() -> String {
        let docs = rootURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("airlift_pairing.plist").path
    }

    public func setActivePairing(path: String) {
        Self.clearPairingRevocation()
        UserDefaults.standard.set(path, forKey: "3105.airlift.customPairingPath")
    }

    public func recordData() throws -> Data {
        guard let path = activePairingPath else {
            throw NSError(domain: "AirLiftPairingStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active pairing file found"])
        }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    public func importRecord(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try validate(data)
        let canonical = canonicalPairingFilePath()
        try data.write(to: URL(fileURLWithPath: canonical), options: .atomic)
        setActivePairing(path: canonical)
    }

    public func importRecord(_ data: Data) throws {
        try validate(data)
        let canonical = canonicalPairingFilePath()
        try data.write(to: URL(fileURLWithPath: canonical), options: .atomic)
        setActivePairing(path: canonical)
    }

    public func removeRecord() throws {
        if let path = activePairingPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        UserDefaults.standard.removeObject(forKey: "3105.airlift.customPairingPath")
        Self.clearPairingRevocation()
    }

    public func validate(_ data: Data) throws {
        var format = PropertyListSerialization.PropertyListFormat.xml
        _ = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    }
}
