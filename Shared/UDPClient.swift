//
//  UDPClient.swift
//

import Foundation
import Network

class UDPClient {
    public typealias OnReceiveData = (Data) -> Void
    public typealias OnEnd = (Error?) -> Void

    public var onReceiveData: OnReceiveData?
    public var onEnd: OnEnd?

    private let connection: NWConnection

    public init?(host: NWEndpoint.Host, port: NWEndpoint.Port, localHost: NWEndpoint.Host? = nil, localPort: NWEndpoint.Port? = nil) {
        let params = NWParameters.udp
        if let localHost = localHost, let localPort = localPort {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: localHost, port: localPort)
        }
        params.allowLocalEndpointReuse = true
        connection = NWConnection(host: host, port: port, using: params)
    }

    public func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] in
            self?.handleStateChange($0)
        }
        setupReceive()
        connection.start(queue: queue)
    }

    public func stop() {
        stop(withError: nil)
    }

    public func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.stop(withError: error)
            }
        }))
    }

    private func setupReceive() {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data = data {
                self?.onReceiveData?(data)
            }
            if let error = error {
                if error != NWError.posix(.ECANCELED) {
                    self?.stop(withError: error)
                }
            } else {
                self?.setupReceive()
            }
        }
    }

    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case let .failed(error):
            stop(withError: error)
        case let .waiting(error):
            stop(withError: error)
        default:
            break
        }
    }

    private func stop(withError error: Error?) {
        connection.stateUpdateHandler = nil
        connection.pathUpdateHandler = nil
        connection.viabilityUpdateHandler = nil
        connection.betterPathUpdateHandler = nil
        connection.cancel()
        if let onEnd = onEnd {
            self.onEnd = nil
            onEnd(error)
        }
    }
}
