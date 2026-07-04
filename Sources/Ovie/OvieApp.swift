import Foundation
import SwiftUI

// MARK: - Configuration
//
// Adapted from Jovie tools/shipping-menu-bar (the proven base per
// DESIGN.md). Ovie adds the ship-ledger section and a restart story that
// is safe by construction: the shipper's startup recovery owns un-stranding
// work, so neither an Ovie restart nor a shipper restart can drop jobs.

enum OvieConfig {
    static let jobName = "codex-issue-shipper"
    static let launchdLabel = "co.jovie.hermes.cron-codex-issue-shipper"
    static let jobsLogPath = "\(NSHomeDirectory())/.hermes/logs/jobs.jsonl"
    static let pauseSentinelPath = "\(NSHomeDirectory())/.hermes/shipping-paused"
    static let maxLogLines = 200

    /// Ovie's admin/ops surface is the Jovie web app's `/hud` route (redirects
    /// to the in-shell ops view). `OVIE_HUD_URL` lets a developer point this at
    /// a local `pnpm dev` server instead of production.
    static let productionHudURL = URL(string: "https://jov.ie/hud")!

    static func hudURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["OVIE_HUD_URL"],
            let url = URL(string: override),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme)
        {
            return url
        }
        return productionHudURL
    }
}

// MARK: - Log event model

struct ShipperEvent: Decodable {
    let job: String
    let event: String
    let ts: String

    let issueCount: Int?
    let dispatchableCount: Int?
    let batchCount: Int?
    let durationMs: Int?
    let error: String?
}

enum ShipperState: String {
    case running, paused, error, idle

    var color: Color {
        switch self {
        case .running: return .green
        case .paused: return .yellow
        case .error: return .red
        case .idle: return .gray
        }
    }

    var label: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .error: return "Error"
        case .idle: return "Idle"
        }
    }
}

struct OvieStatus {
    var state: ShipperState = .idle
    var lastRun: String = "—"
    var dispatchable: Int = 0
    var lastError: String?
    var isPaused: Bool = false
    var inflight: [InflightJob] = []
    var owner: ShipOwner?
    var ownerAlive: Bool = false
}

// MARK: - Log tailer

func tailLog(path: String, lines: Int) -> Data? {
    guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
    defer { fh.closeFile() }

    let fileSize = fh.seekToEndOfFile()
    if fileSize == 0 { return Data() }

    let chunkSize: UInt64 = 4096
    var buffer = Data()
    var newlineCount = 0
    var offset = fileSize

    while offset > 0 && newlineCount < lines {
        let readSize = min(chunkSize, offset)
        offset -= readSize
        fh.seek(toFileOffset: offset)
        guard let chunk = try? fh.read(upToCount: Int(readSize)) else { break }
        buffer = chunk + buffer
        newlineCount = buffer.filter { $0 == 0x0a }.count
    }

    return buffer
}

func parseEvents(data: Data) -> [ShipperEvent] {
    let decoder = JSONDecoder()
    return String(data: data, encoding: .utf8)?
        .split(separator: "\n")
        .compactMap { line in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ShipperEvent.self, from: d)
        } ?? []
}

// MARK: - Status assembly

func buildStatus(events: [ShipperEvent], inflight: [InflightJob], owner: ShipOwner?) -> OvieStatus {
    var status = OvieStatus()
    status.isPaused = FileManager.default.fileExists(atPath: OvieConfig.pauseSentinelPath)
    status.inflight = inflight
    status.owner = owner
    if let pid = owner?.pid {
        status.ownerAlive = ShipLedger.isProcessAlive(pid)
    }

    let shipperEvents = events.filter { $0.job == OvieConfig.jobName }
    let lastStart = shipperEvents.last(where: { $0.event == "start" })
    let lastFinish = shipperEvents.last(where: { $0.event == "finish" })
    let lastFatal = shipperEvents.last(where: { $0.event == "fatal" })

    if let start = lastStart, let finish = lastFinish {
        status.state = start.ts > finish.ts ? .running : .idle
    } else if lastStart != nil {
        status.state = .running
    }
    if status.isPaused { status.state = .paused }
    if let fatal = lastFatal, lastFinish == nil || fatal.ts > lastFinish!.ts {
        status.lastError = fatal.error
        if !status.isPaused { status.state = .error }
    }
    if let finish = lastFinish {
        status.lastRun = formatTimestamp(finish.ts)
    }
    if let scanned = shipperEvents.last(where: { $0.event == "scanned" }) {
        status.dispatchable = scanned.dispatchableCount ?? 0
    }
    return status
}

func formatTimestamp(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: iso) ?? {
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)
    }()
    guard let date else { return iso }
    let out = DateFormatter()
    out.dateStyle = .none
    out.timeStyle = .medium
    return out.string(from: date)
}

// MARK: - Controls

func pauseShipping() {
    FileManager.default.createFile(
        atPath: OvieConfig.pauseSentinelPath,
        contents: Data("paused by Ovie\n".utf8)
    )
}

func resumeShipping() {
    try? FileManager.default.removeItem(atPath: OvieConfig.pauseSentinelPath)
}

/// Safe by construction: `kickstart -k` kills any in-flight run, and the
/// next shipper start recovers every journaled claim whose owner died
/// (ship-ledger startup recovery). Nothing is stranded.
func restartShipper() {
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["kickstart", "-k", "gui/\(getuid())/\(OvieConfig.launchdLabel)"]
    try? task.run()
}

/// Ovie restarting itself never drops ship work — the shipper owns the
/// jobs and the ledger owns recovery. This is the slice-1 guarantee, and
/// the same property makes auto-update safe to add on top.
func relaunchOvie() {
    let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
    let task = Process()
    task.launchPath = path
    try? task.run()
    NSApplication.shared.terminate(nil)
}

/// Hands off from the menu bar to the deep ops view: opens the Jovie web
/// app in the system default browser, same as the Jovie Electron app's
/// external-link handoff (`NSWorkspace` under `shell.openExternal`). No
/// embedded webview — Swift stays a menu bar, the web app is the surface.
func openOvieHud() {
    NSWorkspace.shared.open(OvieConfig.hudURL())
}

// MARK: - App

@main
struct OvieApp: App {
    @StateObject private var model = OvieModel()

    var body: some Scene {
        MenuBarExtra {
            OvieMenuContent(model: model)
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(model.status.state.color)
                    .frame(width: 8, height: 8)
                Image(systemName: "shippingbox")
            }
        }
    }
}

@MainActor
final class OvieModel: ObservableObject {
    @Published var status = OvieStatus()
    @Published var gbrain = GBrainHealth()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let events = tailLog(path: OvieConfig.jobsLogPath, lines: OvieConfig.maxLogLines)
            .map(parseEvents) ?? []
        status = buildStatus(
            events: events,
            inflight: ShipLedger.readJournal(),
            owner: ShipLedger.readOwner()
        )
        Task { [weak self] in
            let health = await checkGBrainHealth()
            self?.gbrain = health
        }
    }
}

struct OvieMenuContent: View {
    @ObservedObject var model: OvieModel

    var body: some View {
        Section {
            HStack {
                Circle()
                    .fill(model.status.state.color)
                    .frame(width: 10, height: 10)
                Text("Ovie: \(model.status.state.label)")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 2)
        }

        Divider()

        Section {
            LabeledContent("Dispatchable issues", value: "\(model.status.dispatchable)")
            LabeledContent("In-flight jobs", value: "\(model.status.inflight.count)")
            LabeledContent("Last run", value: model.status.lastRun)
            if let owner = model.status.owner {
                LabeledContent(
                    "Ship owner",
                    value: "\(owner.caller ?? "?") pid \(owner.pid.map(String.init) ?? "?")\(model.status.ownerAlive ? "" : " (dead — next start recovers)")"
                )
            }
        }

        Divider()

        Section {
            HStack {
                Circle()
                    .fill(model.gbrain.state.color)
                    .frame(width: 10, height: 10)
                Text("gbrain: \(model.gbrain.state.label)")
                Spacer()
            }
            .padding(.vertical, 2)
            if let latency = model.gbrain.latencyMs {
                LabeledContent("Latency", value: "\(latency) ms")
            }
            LabeledContent("Last check", value: model.gbrain.lastCheckedLabel)
            if model.gbrain.state == .down, let detail = model.gbrain.statusText {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }

        if !model.status.inflight.isEmpty {
            Divider()
            Section("In-flight (ledger)") {
                ForEach(model.status.inflight, id: \.issue) { job in
                    Text("\(job.repo)#\(job.issue) → \(job.branch)")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }

        if let err = model.status.lastError {
            Divider()
            Section("Last error") {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(3)
            }
        }

        Divider()

        Section {
            Button("Open Ovie") { openOvieHud() }
            if model.status.isPaused {
                Button("Resume shipping") {
                    resumeShipping()
                    model.refresh()
                }
            } else {
                Button("Pause shipping") {
                    pauseShipping()
                    model.refresh()
                }
            }
            Button("Restart shipper (ledger-safe)") {
                restartShipper()
                model.refresh()
            }
            Button("Relaunch Ovie") { relaunchOvie() }
            Button("Refresh") { model.refresh() }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
