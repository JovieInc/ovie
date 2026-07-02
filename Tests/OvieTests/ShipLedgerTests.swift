import XCTest
@testable import Ovie

final class ShipLedgerTests: XCTestCase {
    private let sampleJournal = """
    [
      {
        "job": "codex-issue-shipper",
        "repo": "JovieInc/Jovie",
        "issue": 12723,
        "branch": "codex/gh-12723-dup-shippers",
        "worktree": "/tmp/jovie-worktrees/gh-12723",
        "pid": 12345,
        "startedAt": "2026-07-02T18:00:00.000Z"
      },
      {
        "job": "codex-issue-shipper",
        "repo": "JovieInc/Ops",
        "issue": 135,
        "branch": "codex/gh-135-taste-inbox",
        "worktree": "/tmp/jovie-worktrees/gh-135",
        "pid": 54321,
        "startedAt": "2026-07-02T18:05:00.000Z"
      }
    ]
    """.data(using: .utf8)!

    func testParsesJournalWrittenByShipLedgerTs() {
        let jobs = ShipLedger.parseJournal(sampleJournal)
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs[0].issue, 12723)
        XCTAssertEqual(jobs[0].repo, "JovieInc/Jovie")
        XCTAssertEqual(jobs[1].pid, 54321)
    }

    func testCorruptJournalReadsAsEmpty() {
        XCTAssertEqual(ShipLedger.parseJournal(Data("{not json".utf8)), [])
        XCTAssertEqual(ShipLedger.parseJournal(Data("{\"an\":\"object\"}".utf8)), [])
        XCTAssertEqual(ShipLedger.parseJournal(Data()), [])
    }

    func testMissingJournalFileReadsAsEmpty() {
        XCTAssertEqual(ShipLedger.readJournal(path: "/nonexistent/journal.json"), [])
    }

    func testParsesOwnerLockWrittenByHeavyJobLockTs() {
        let lock = Data(
            "{\"caller\":\"codex-issue-shipper\",\"pid\":999,\"ts\":1782977352000}".utf8
        )
        let owner = ShipLedger.parseOwner(lock)
        XCTAssertEqual(owner?.caller, "codex-issue-shipper")
        XCTAssertEqual(owner?.pid, 999)
    }

    func testLiveJobsFiltersDeadOwners() {
        let jobs = ShipLedger.parseJournal(sampleJournal)
        let live = ShipLedger.liveJobs(jobs) { $0 == 54321 }
        XCTAssertEqual(live.map(\.issue), [135])
    }

    func testOwnProcessIsAlive() {
        XCTAssertTrue(ShipLedger.isProcessAlive(Int(ProcessInfo.processInfo.processIdentifier)))
        XCTAssertFalse(ShipLedger.isProcessAlive(99_999_999))
    }
}
