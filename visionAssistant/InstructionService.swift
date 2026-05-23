import Foundation
import Network

/// Listens on port 3031 for POST /instruction from Claude/screenpipe.
/// Also polls screenpipe's health endpoint to report connection status.
@MainActor
final class InstructionService: ObservableObject {
    static let shared = InstructionService()

    @Published var current: Instruction?
    @Published var history: [Instruction] = []
    @Published var isServerRunning = false
    @Published var screenpipeConnected = false

    private var listener: NWListener?
    private var healthTimer: Timer?
    // 3031 est réservé par macOS pour EPPC (Apple Events), bind impossible.
    private let serverPort: NWEndpoint.Port = 3131

    func start() {
        startServer()
        startHealthPolling()
    }

    func dismiss() {
        current = nil
    }

    // MARK: - HTTP server

    private func startServer() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let l = try? NWListener(using: params, on: serverPort) else { return }
        listener = l

        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isServerRunning = state == .ready
            }
        }

        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.handle(conn) }
        }

        l.start(queue: .global(qos: .userInteractive))
    }

    private func handle(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readRequest(connection, buffer: Data())
            case .failed, .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInteractive))
    }

    nonisolated private func readRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] chunk, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var buf = buffer
            if let chunk, !chunk.isEmpty { buf.append(chunk) }

            let sep = Data("\r\n\r\n".utf8)
            guard let headerRange = buf.range(of: sep) else {
                if isComplete || error != nil { connection.cancel(); return }
                self.readRequest(connection, buffer: buf)
                return
            }

            let headerStr = String(data: buf[..<headerRange.lowerBound], encoding: .utf8) ?? ""
            let path = Self.extractPath(from: headerStr)
            let contentLength = Self.extractContentLength(from: headerStr)
            let body = Data(buf[headerRange.upperBound...])

            // Attente du corps complet si Content-Length n'est pas encore satisfait
            if body.count < contentLength {
                if isComplete || error != nil {
                    self.send(connection, status: 400)
                    return
                }
                self.readRequest(connection, buffer: buf)
                return
            }

            let fullBody = body.prefix(contentLength)

            Task { @MainActor in
                if path == "/dismiss" {
                    self.dismiss()
                } else if !fullBody.isEmpty {
                    self.ingest(Data(fullBody))
                }
                self.send(connection, status: 200)
            }
        }
    }

    nonisolated private func send(_ connection: NWConnection, status: Int) {
        let reason = status == 200 ? "OK" : "Bad Request"
        let body = status == 200 ? "ok" : "err"
        let response = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    nonisolated private static func extractPath(from header: String) -> String {
        guard let firstLine = header.split(separator: "\r\n").first else { return "/" }
        let parts = firstLine.split(separator: " ")
        return parts.count >= 2 ? String(parts[1]) : "/"
    }

    nonisolated private static func extractContentLength(from header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }

    private func ingest(_ body: Data) {
        guard let instruction = try? JSONDecoder().decode(Instruction.self, from: body) else { return }
        Task { @MainActor in
            self.current = instruction
            self.history.insert(instruction, at: 0)
            self.scheduleAutoDismiss(for: instruction.id)
        }
    }

    // MARK: - Auto-dismiss

    private var autoDismissTask: Task<Void, Never>?
    private let autoDismissAfter: Duration = .seconds(12)

    private func scheduleAutoDismiss(for id: UUID) {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.autoDismissAfter ?? .seconds(12))
            guard !Task.isCancelled, self?.current?.id == id else { return }
            self?.dismiss()
        }
    }

    // MARK: - Screenpipe health polling

    private func startHealthPolling() {
        checkScreenpipeHealth()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkScreenpipeHealth() }
        }
    }

    private func checkScreenpipeHealth() {
        guard let url = URL(string: "http://localhost:3030/health") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] _, response, _ in
            let connected = (response as? HTTPURLResponse)?.statusCode == 200
            Task { @MainActor in
                self?.screenpipeConnected = connected
            }
        }.resume()
    }
}
