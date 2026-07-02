import Foundation

// MARK: - Ship ledger (cross-process contract)
//
// The shipper (Jovie scripts/hermes/lib/ship-ledger.ts) owns these files;
// Ovie only reads them. Formats are documented in LEDGER.md. Because claim
// recovery is the SHIPPER's startup responsibility, Ovie (and the shipper
// itself) can restart at any moment without dropping in-flight work — the
// next shipper start releases any claim whose owner pid is dead.

public enum LedgerPaths {
    /// Machine-global by design — never derive these from HERMES_HOME
    /// (profile-scoped overrides are how two "singleton" shippers raced
    /// one queue; see JovieInc/Jovie#12723).
    public static var stateDir: String { "\(NSHomeDirectory())/.hermes/state" }
    public static var journal: String { "\(stateDir)/inflight-ship-jobs.json" }
    public static var ownerLock: String { "\(stateDir)/ship-owner.lock" }
}

public struct InflightJob: Decodable, Equatable {
    public let job: String
    public let repo: String
    public let issue: Int
    public let branch: String
    public let worktree: String
    public let pid: Int
    public let startedAt: String
}

public struct ShipOwner: Decodable, Equatable {
    public let caller: String?
    public let pid: Int?
    public let ts: Double?
}

public enum ShipLedger {
    /// Corrupt or missing journal reads as empty — the shipper applies the
    /// same tolerance, so both sides degrade identically.
    public static func parseJournal(_ data: Data) -> [InflightJob] {
        (try? JSONDecoder().decode([InflightJob].self, from: data)) ?? []
    }

    public static func readJournal(path: String = LedgerPaths.journal) -> [InflightJob] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        return parseJournal(data)
    }

    public static func parseOwner(_ data: Data) -> ShipOwner? {
        try? JSONDecoder().decode(ShipOwner.self, from: data)
    }

    public static func readOwner(path: String = LedgerPaths.ownerLock) -> ShipOwner? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return parseOwner(data)
    }

    public static func isProcessAlive(_ pid: Int) -> Bool {
        kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    /// Jobs whose owner process is still running.
    public static func liveJobs(
        _ jobs: [InflightJob],
        isAlive: (Int) -> Bool = isProcessAlive
    ) -> [InflightJob] {
        jobs.filter { isAlive($0.pid) }
    }
}
