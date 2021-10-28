//
//  UDPClient.swift
//  UDPSendTest
//
//  Created by Markus Fritze on 05.10.21.
//

import Foundation
import Network

class UDPClient {
    // MARK: - Public typealiases

    public typealias OnReceiveData = (Data) -> Void
    public typealias OnEnd = (Error?) -> Void

    // MARK: - Public properties

    public let host: NWEndpoint.Host
    public let port: NWEndpoint.Port
    public var onReceiveData: OnReceiveData?
    public var onEnd: OnEnd?

    // MARK: - Private properties

    private let nwConnection: NWConnection

    // MARK: - Initializers

    public init?(host: NWEndpoint.Host, port: NWEndpoint.Port, localHost: NWEndpoint.Host? = nil, localPort: NWEndpoint.Port? = nil) {
//        print("UDPClient(host=\(host),port=\(port))")
        self.host = host
        self.port = port
        let params = NWParameters.udp
        if let localHost = localHost, let localPort = localPort {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: localHost, port: localPort)
        }
        params.allowLocalEndpointReuse = true
        nwConnection = NWConnection(host: host, port: port, using: params)
    }

    // MARK: - Public methods

    public func start(on queue: DispatchQueue) {
//        print("UDPClient.start(on=\(queue))")
        nwConnection.stateUpdateHandler = { [weak self] in
            self?.handleStateChange($0)
        }
        setupReceive()
        nwConnection.start(queue: queue)
    }

    public func stop() {
//        print("UDPClient.stop()")
        stop(withError: nil)
    }

    public func send(_ data: Data) {
//        print("UDPClient.send(data=\(data))")
        nwConnection.send(content: data, completion: .contentProcessed({ [weak self] error in
//            print("UDPClient.NWConnection.sendCompletion(error=\(String(describing: error)))")
            if let error = error {
                self?.stop(withError: error)
            }
        }))
    }

    // MARK: - Private methods

    private func setupReceive() {
//        print("UDPClient.setupReceive()")
        nwConnection.receiveMessage { [weak self] data, _, _, error in
//            print("UDPClient.NWConnection.receiveMessageCompletion(data=\(String(describing: data?.hexEncodedString())),context=\(String(describing: context)),isComplete=\(isComplete),error=\(String(describing: error)))")
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
//        print("UDPClient.handleStateChange(\(state))")
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
//        print("UDPClient.stop(error=\(String(describing: error)))")
        nwConnection.stateUpdateHandler = nil
        nwConnection.pathUpdateHandler = nil
        nwConnection.viabilityUpdateHandler = nil
        nwConnection.betterPathUpdateHandler = nil
        nwConnection.cancel()
        if let onEnd = onEnd {
            self.onEnd = nil
            onEnd(error)
        }
    }
}
