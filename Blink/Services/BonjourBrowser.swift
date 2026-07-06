#if os(visionOS)
import Foundation
import Network

@MainActor
final class BonjourBrowser {

    static let shared = BonjourBrowser()

    private let serviceType = "_blink._tcp"
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var reconnectTask: Task<Void, Never>?

    private(set) var isSynced: Bool = false
    private(set) var isLeader: Bool = true
    private var leaderDecided: Bool = false

    private init() {}

    func start() {
        guard browser == nil else { return }

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    print("[BonjourBrowser] Browsing for \(self.serviceType)")
                case .failed(let error):
                    print("[BonjourBrowser] Browse failed: \(error)")
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self, self.connection == nil else { return }
                if let result = results.first {
                    self.connectTo(result.endpoint)
                }
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        isSynced = false
    }

    func broadcastCurrentState() {
        guard let connection, isSynced else { return }

        let state = SyncMerge.currentState()
        guard let json = try? encoder.encode(state) else { return }
        let framed = SyncFraming.frame(json)

        connection.send(content: framed, completion: .contentProcessed { error in
            if let error {
                print("[BonjourBrowser] Send error: \(error)")
            }
        })
    }

    // MARK: - Private

    private func connectTo(_ endpoint: NWEndpoint) {
        print("[BonjourBrowser] Connecting to \(endpoint)")
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    print("[BonjourBrowser] Connected to Mac")
                    self.isSynced = true
                    self.receiveBuffer = Data()
                    self.receiveNextMessage(on: connection)
                case .failed, .cancelled:
                    print("[BonjourBrowser] Disconnected from Mac")
                    self.isSynced = false
                    self.leaderDecided = false
                    self.isLeader = true
                    self.connection = nil
                    self.scheduleReconnect()
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        self.connection = connection
    }

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }

                if let content {
                    self.receiveBuffer.append(content)
                    self.processBuffer()
                }

                if let error {
                    print("[BonjourBrowser] Receive error: \(error)")
                    return
                }

                if isComplete {
                    connection.cancel()
                    return
                }

                self.receiveNextMessage(on: connection)
            }
        }
    }

    private func processBuffer() {
        while receiveBuffer.count >= 4 {
            var rawLength: UInt32 = 0
            let base = receiveBuffer.startIndex
            _ = withUnsafeMutableBytes(of: &rawLength) {
                receiveBuffer.copyBytes(to: $0, from: base..<(base + 4))
            }
            let length = rawLength.bigEndian
            let totalNeeded = 4 + Int(length)

            guard length > 0, length < 1_000_000 else {
                print("[BonjourBrowser] Bad frame length: \(length), clearing buffer")
                receiveBuffer.removeAll()
                return
            }

            guard receiveBuffer.count >= totalNeeded else { break }

            let jsonData = receiveBuffer.subdata(in: (base + 4)..<(base + totalNeeded))
            receiveBuffer = Data(receiveBuffer.suffix(from: base + totalNeeded))

            do {
                let state = try decoder.decode(BlinkSyncState.self, from: jsonData)
                if !leaderDecided {
                    let localElapsed = AppState.shared.workElapsedSeconds
                    isLeader = localElapsed > state.workElapsedSeconds
                    leaderDecided = true
                    print("[BonjourBrowser] Leader decided: \(isLeader ? "visionOS" : "Mac") (local=\(localElapsed) remote=\(state.workElapsedSeconds))")
                }
                if !isLeader {
                    SyncMerge.apply(state)
                } else if SyncMerge.shouldApplyRemote(state) {
                    SyncMerge.apply(state)
                    isLeader = false
                    print("[BonjourBrowser] Leadership transferred to Mac (state transition)")
                }
            } catch {
                print("[BonjourBrowser] Decode error: \(error)")
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, self.connection == nil else { return }
            print("[BonjourBrowser] Attempting reconnect...")
            if let result = self.browser?.browseResults.first {
                self.connectTo(result.endpoint)
            }
        }
    }
}
#endif
