#if os(macOS)
import Foundation
import Network

@MainActor
final class BonjourAdvertiser {

    static let shared = BonjourAdvertiser()

    private let serviceType = "_blink._tcp"
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]
    private(set) var isLeader: Bool = true
    private var leaderDecided: Bool = false
    var hasClients: Bool { !connections.isEmpty }

    private init() {}

    func start() {
        guard listener == nil else { return }

        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let listener = try NWListener(using: params)
            listener.service = NWListener.Service(type: serviceType)

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        print("[BonjourAdvertiser] Listening")
                    case .failed(let error):
                        print("[BonjourAdvertiser] Listener failed: \(error)")
                        self?.listener = nil
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener.start(queue: .main)
            self.listener = listener
        } catch {
            print("[BonjourAdvertiser] Failed to create listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        receiveBuffers.removeAll()
    }

    func broadcastCurrentState() {
        guard !connections.isEmpty else { return }

        let state = SyncMerge.currentState()
        guard let json = try? encoder.encode(state) else { return }
        let framed = SyncFraming.frame(json)

        for connection in connections {
            connection.send(content: framed, completion: .contentProcessed { error in
                if let error {
                    print("[BonjourAdvertiser] Send error: \(error)")
                }
            })
        }
    }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        print("[BonjourAdvertiser] New client connected")
        connections.append(connection)
        receiveBuffers[ObjectIdentifier(connection)] = Data()

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("[BonjourAdvertiser] Client ready")
                    self?.receiveNextMessage(on: connection)
                case .failed, .cancelled:
                    print("[BonjourAdvertiser] Client disconnected")
                    self?.connections.removeAll { $0 === connection }
                    self?.receiveBuffers.removeValue(forKey: ObjectIdentifier(connection))
                    if self?.connections.isEmpty == true {
                        self?.leaderDecided = false
                        self?.isLeader = true
                    }
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                let connId = ObjectIdentifier(connection)

                if let content {
                    self.receiveBuffers[connId, default: Data()].append(content)
                    self.processBuffer(for: connection)
                }

                if let error {
                    print("[BonjourAdvertiser] Receive error: \(error)")
                    return
                }

                if isComplete {
                    return
                }

                self.receiveNextMessage(on: connection)
            }
        }
    }

    private func processBuffer(for connection: NWConnection) {
        let connId = ObjectIdentifier(connection)
        guard var buffer = receiveBuffers[connId] else { return }

        while buffer.count >= 4 {
            var rawLength: UInt32 = 0
            let base = buffer.startIndex
            _ = withUnsafeMutableBytes(of: &rawLength) {
                buffer.copyBytes(to: $0, from: base..<(base + 4))
            }
            let length = rawLength.bigEndian
            let totalNeeded = 4 + Int(length)

            guard length > 0, length < 1_000_000 else {
                buffer.removeAll()
                break
            }

            guard buffer.count >= totalNeeded else { break }

            let jsonData = buffer.subdata(in: (base + 4)..<(base + totalNeeded))
            buffer = Data(buffer.suffix(from: base + totalNeeded))

            do {
                let state = try decoder.decode(BlinkSyncState.self, from: jsonData)
                if !leaderDecided {
                    let localElapsed = AppState.shared.workElapsedSeconds
                    isLeader = localElapsed >= state.workElapsedSeconds
                    leaderDecided = true
                    print("[BonjourAdvertiser] Leader decided: \(isLeader ? "Mac" : "visionOS") (local=\(localElapsed) remote=\(state.workElapsedSeconds))")
                }
                if !isLeader {
                    SyncMerge.apply(state)
                } else if SyncMerge.shouldApplyRemote(state) {
                    SyncMerge.apply(state)
                    isLeader = false
                    print("[BonjourAdvertiser] Leadership transferred to visionOS (state transition)")
                }
            } catch {
                print("[BonjourAdvertiser] Decode error: \(error)")
            }
        }

        receiveBuffers[connId] = buffer
    }
}
#endif
