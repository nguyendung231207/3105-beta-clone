import Foundation

public enum ExploitRoute: String, CaseIterable, Identifiable {
    case kernel = "Kernel (kexploit_opa334)"
    case badQuery = "bad_query (MCMRetainedLease)"
    case airLift = "AirLift (RPPairing + LocalDevVPN + AirTraffic)"
    case unsupported = "Unsupported"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .kernel: return "Kernel"
        case .badQuery: return "bad_query"
        case .airLift: return "AirLift"
        case .unsupported: return "Không hỗ trợ"
        }
    }
}

public enum ExploitSupportPolicy {
    public static let verifiedIOS17Range = "17.0–17.7.x"
    public static let verifiedIOS18Range = "18.0–18.7.1"
    public static let verifiedIOS26Range = "26.0–26.6.1"

    /// Verified beta builds supporting bad_query
    public static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    public static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    public static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    public static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        if major == 17 { return minor <= 7 }
        if major == 18 { return minor < 7 || (minor == 7 && patch <= 1) }
        return false
    }

    /// Determines the appropriate exploit execution route for the running iOS version
    public static func determineRoute(major: Int, minor: Int, patch: Int, build: String, forceAirLift: Bool = false) -> ExploitRoute {
        if forceAirLift {
            return .airLift
        }

        // iOS 17 - 18: Kernel exploit available
        if major == 17 || major == 18 {
            return .kernel
        }

        // iOS 26: bad_query sandbox bypass
        if major == 26 {
            return .badQuery
        }

        // iOS 27:
        if major == 27 {
            // Beta 1..4 can still use bad_query
            if iOS27BetaNumber(for: build) != nil {
                return .badQuery
            }
            // iOS 27 Official / Release or newer betas (beta 5+):
            // Apple patched bad_query and kernel flaws -> Must use AirLift!
            return .airLift
        }

        // Newer major versions default to AirLift
        if major > 27 {
            return .airLift
        }

        return .unsupported
    }

    public static func isAirLiftRequired(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if major > 27 { return true }
        if major == 27 {
            return iOS27BetaNumber(for: build) == nil
        }
        return false
    }

    public static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        return determineRoute(major: major, minor: minor, patch: patch, build: build) != .unsupported
    }
}

