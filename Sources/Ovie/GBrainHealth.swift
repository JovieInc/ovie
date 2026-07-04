import Foundation
import SwiftUI

// MARK: - gbrain health check (issue #13, status-display slice)
//
// Ovie polls the gbrain HTTP server's /health endpoint on the same 15s
// cadence as the shipper log refresh and surfaces the result in the menu.
// Lifecycle management (auto-restart with backoff) is a follow-up slice.

enum GBrainConfig {
    static let healthURL = URL(string: "http://127.0.0.1:7801/health")!
    static let requestTimeout: TimeInterval = 3.0
}

enum GBrainState: String {
    case running, down, checking

    var color: Color {
        switch self {
        case .running: return .green
        case .down: return .red
        case .checking: return .gray
        }
    }

    var label: String {
        switch self {
        case .running: return "Running"
        case .down: return "Down"
        case .checking: return "Checking…"
        }
    }
}

struct GBrainHealth {
    var state: GBrainState = .checking
    var latencyMs: Int?
    var statusText: String?
    var lastChecked: Date?

    var lastCheckedLabel: String {
        guard let lastChecked else { return "—" }
        let out = DateFormatter()
        out.dateStyle = .none
        out.timeStyle = .medium
        return out.string(from: lastChecked)
    }
}

/// One-shot health probe against the local gbrain HTTP server. Short
/// timeout so a down server never stalls the menu refresh cycle.
func checkGBrainHealth() async -> GBrainHealth {
    var health = GBrainHealth()
    health.lastChecked = Date()

    var request = URLRequest(url: GBrainConfig.healthURL)
    request.timeoutInterval = GBrainConfig.requestTimeout

    let started = Date()
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        health.latencyMs = Int(Date().timeIntervalSince(started) * 1000)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            health.state = .down
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            health.statusText = "HTTP \(code)"
            return health
        }
        health.state = .running
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? String
        {
            health.statusText = status
        }
    } catch {
        health.state = .down
        health.statusText = error.localizedDescription
    }
    return health
}
