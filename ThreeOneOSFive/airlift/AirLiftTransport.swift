//
// AirLiftTransport.swift
// Decompiled / Reconstructed from 3105.app (YangJiiii / 3105 Offline v2)
// Module: _105 (3105)
//

import Foundation

public struct AirLiftFileReference: Equatable {
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date?
}

public struct AirLiftDirectoryEntry: Equatable {
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let size: Int64
}

public struct AirLiftApplicationRecord: Equatable {
    public let bundleID: String
    public let bundlePath: String
    public let dataContainerPath: String?
    public let displayName: String?
}

public enum AirLiftTransportError: LocalizedError {
    case tunnelFailed(String)
    case afcError(String)
    case fileNotFound(String)
    case accessDenied(String)
    case writeFailed(String)
    case invalidTarget(String)
    
    public var errorDescription: String? {
        switch self {
        case .tunnelFailed(let msg): return "AirLift tunnel error: \(msg)"
        case .afcError(let msg): return "AFC service error: \(msg)"
        case .fileNotFound(let path): return "File not found: \(path)"
        case .accessDenied(let path): return "Access denied to \(path)"
        case .writeFailed(let msg): return "AirLift write failed: \(msg)"
        case .invalidTarget(let msg): return "Invalid target: \(msg)"
        }
    }
}

public enum AirLiftTransport {
    private static let transferLock = NSRecursiveLock()
    private static let capabilityLock = NSLock()
    private static let applicationLock = NSLock()

    /// Default device loopback IP provided by LocalDevVPN
    public static let defaultDeviceIP: String = "10.7.0.1"

    /// Reads data from multiple absolute device paths via AirLift
    public static func readExisting(fromAbsolutePaths paths: [String], store: AirLiftPairingStore) throws -> [String: Data] {
        transferLock.lock()
        defer { transferLock.unlock() }

        guard let pairingPath = store.activePairingPath, !pairingPath.isEmpty else {
            throw AirLiftTransportError.tunnelFailed("Missing active pairing record")
        }

        var results: [String: Data] = [:]
        for path in paths {
            if let data = try? readOneLocked(path: path, pairingPath: pairingPath) {
                results[path] = data
            }
        }
        return results
    }

    private static func readOneLocked(path: String, pairingPath: String) throws -> Data {
        var error: NSError?
        guard let data = ATCGlue.readFileArbitrary(
            withDeviceIP: defaultDeviceIP,
            pairingPath: pairingPath,
            absolutePath: path,
            maximumBytes: 100 * 1024 * 1024,
            error: &error
        ) else {
            throw AirLiftTransportError.fileNotFound(error?.localizedDescription ?? path)
        }
        return data
    }

    /// Lists entries in a given file reference location
    public static func listEntries(reference: AirLiftFileReference, store: AirLiftPairingStore) throws -> [AirLiftDirectoryEntry] {
        transferLock.lock()
        defer { transferLock.unlock() }

        guard let pairingPath = store.activePairingPath else {
            throw AirLiftTransportError.tunnelFailed("No pairing file available")
        }

        var error: NSError?
        guard let items = ATCGlue.listDirectoryArbitrary(
            withDeviceIP: defaultDeviceIP,
            pairingPath: pairingPath,
            absolutePath: reference.path,
            error: &error
        ) else {
            throw AirLiftTransportError.afcError(error?.localizedDescription ?? "Failed to list directory")
        }

        return items.map { name in
            AirLiftDirectoryEntry(
                name: name,
                relativePath: (reference.path as NSString).appendingPathComponent(name),
                isDirectory: false,
                size: 0
            )
        }
    }

    /// Obtains application container record using InstallationProxy via RSD
    public static func application(bundleID: String, store: AirLiftPairingStore) throws -> AirLiftApplicationRecord {
        applicationLock.lock()
        defer { applicationLock.unlock() }

        guard let pairingPath = store.activePairingPath else {
            throw AirLiftTransportError.tunnelFailed("No pairing file available")
        }

        var error: NSError?
        guard let dict = ATCGlue.application(withBundleID: bundleID, deviceIP: defaultDeviceIP, pairingPath: pairingPath, error: &error) else {
            throw AirLiftTransportError.fileNotFound("App with bundle ID \(bundleID) not found")
        }

        return AirLiftApplicationRecord(
            bundleID: bundleID,
            bundlePath: dict["Path"] as? String ?? "",
            dataContainerPath: dict["Container"] as? String,
            displayName: dict["CFBundleDisplayName"] as? String ?? dict["CFBundleName"] as? String
        )
    }

    /// Injects or writes files directly outside sandbox using Books staging & AirTraffic exploit
    public static func writeFiles(
        targetDirectories: [String],
        fileNames: [String],
        datas: [Data],
        store: AirLiftPairingStore
    ) throws {
        transferLock.lock()
        defer { transferLock.unlock() }

        guard let pairingPath = store.activePairingPath else {
            throw AirLiftTransportError.tunnelFailed("Pairing file required for AirLift write")
        }

        var error: NSError?
        let success = ATCGlue.writeFilesArbitrary(
            withDeviceIP: defaultDeviceIP,
            pairingPath: pairingPath,
            targetDirectories: targetDirectories,
            fileNames: fileNames,
            data: datas,
            error: &error
        )

        if !success {
            throw AirLiftTransportError.writeFailed(error?.localizedDescription ?? "Unknown write error")
        }
    }
}
