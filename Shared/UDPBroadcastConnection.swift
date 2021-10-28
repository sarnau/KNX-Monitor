//
//  UDPBroadcastConnection.swift
//  UDPBroadcast
//
//  Created by Gunter Hager on 10.02.16.
//  Copyright © 2016 Gunter Hager. All rights reserved.
//

import Darwin
import Foundation
import Network

// Addresses

let INADDR_ANY = in_addr(s_addr: 0)

/// An object representing the UDP broadcast connection. Uses a dispatch source to handle the incoming traffic on the UDP socket.
open class UDPBroadcastConnection {
    // MARK: Properties

    /// The address of the UDP socket.
    var address: sockaddr_in

    /// The broadcast group address
    var inaddr_broadcast: in_addr

    /// Type of a closure that handles incoming UDP packets.
    public typealias ReceiveHandler = (_ ipAddress: String, _ port: Int, _ response: Data) -> Void
    /// Closure that handles incoming UDP packets.
    var handler: ReceiveHandler?

    /// Type of a closure that handles errors that were encountered during receiving UDP packets.
    public typealias ErrorHandler = (_ error: ConnectionError) -> Void
    /// Closure that handles errors that were encountered during receiving UDP packets.
    var errorHandler: ErrorHandler?

    /// A dispatch source for reading data from the UDP socket.
    var responseSource: DispatchSourceRead?

    /// The dispatch queue to run responseSource & reconnection on
    var dispatchQueue: DispatchQueue = DispatchQueue.main

    /// Bind to port to start listening without first sending a message
    var shouldBeBound: Bool = false

    // MARK: Initializers

    /// Initializes the UDP connection with the correct port address.

    /// - Note: This doesn't open a socket! The socket is opened transparently as needed when sending broadcast messages. If you want to open a socket immediately, use the `bindIt` parameter. This will also try to reopen the socket if it gets closed.
    ///
    /// - Parameters:
    ///   - port: Number of the UDP port to use.
    ///   - bindIt: Opens a port immediately if true, on demand if false. Default is false.
    ///   - handler: Handler that gets called when data is received.
    ///   - errorHandler: Handler that gets called when an error occurs.
    /// - Throws: Throws a `ConnectionError` if an error occurs.
    public init(mcast_port: NWEndpoint.Port, mcast_group: IPv4Address = .any, bindIt: Bool = false, handler: ReceiveHandler?, errorHandler: ErrorHandler?) throws {
        inaddr_broadcast = in_addr(s_addr: UDPBroadcastConnection.htonsIPv4(ipv4: mcast_group.rawUInt32Value))

        address = sockaddr_in(
            sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: UDPBroadcastConnection.htonsPort(port: mcast_port.rawValue),
            sin_addr: inaddr_broadcast,
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        self.handler = handler
        self.errorHandler = errorHandler
        shouldBeBound = bindIt
        if bindIt {
            try createSocket()
        }
    }

    deinit {
        if responseSource != nil {
            responseSource!.cancel()
        }
    }

    // MARK: Interface

    /// Send broadcast message.
    ///
    /// - Parameter message: Message to send via broadcast.
    /// - Throws: Throws a `ConnectionError` if an error occurs.
    open func sendBroadcast(_ message: String) throws {
        guard let data = message.data(using: .utf8) else { throw ConnectionError.messageEncodingFailed }
        try sendBroadcast(data)
    }

    /// Send broadcast data.
    ///
    /// - Parameter data: Data to send via broadcast.
    /// - Throws: Throws a `ConnectionError` if an error occurs.
    open func sendBroadcast(_ data: Data) throws {
        if responseSource == nil {
            try createSocket()
        }
        guard let source = responseSource else { return }

        let socketLength = socklen_t(address.sin_len)
        try data.withUnsafeBytes { broadcastMessage in
            let sent = withUnsafeMutablePointer(to: &address) { pointer -> Int in
                let memory = UnsafeRawPointer(pointer).bindMemory(to: sockaddr.self, capacity: 1)
                return sendto(Int32(source.handle), broadcastMessage.baseAddress, data.count, 0, memory, socketLength)
            }
            if sent <= 0 {
                closeConnection()
                throw ConnectionError.sendingMessageFailed(code: errno)
            }
        }
    }

    /// Close the connection.
    ///
    /// - Parameter reopen: Automatically reopens the connection if true. Defaults to true.
    open func closeConnection(reopen: Bool = true) {
        if let source = responseSource {
            source.cancel()
            responseSource = nil
        }
        if shouldBeBound && reopen {
            dispatchQueue.async {
                do {
                    try self.createSocket()
                } catch {
                    self.errorHandler?(ConnectionError.reopeningSocketFailed(error: error))
                }
            }
        }
    }

    // MARK: - Private

    /// Create a UDP socket for broadcasting and set up cancel and event handlers
    ///
    /// - Throws: Throws a `ConnectionError` if an error occurs.
    private func createSocket() throws {
        // Create new socket
        let newSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard newSocket > 0 else { throw ConnectionError.createSocketFailed }

        // Enable broadcast on socket
        var broadcastEnable = Int32(1)
        let ret = setsockopt(newSocket, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<UInt32>.size))
        if ret == -1 {
            close(newSocket)
            throw ConnectionError.enableBroadcastFailed
        }

        // Bind socket if needed
        if shouldBeBound {
            var saddr = sockaddr()
            var saddr_in = sockaddr_in(
                sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
                sin_family: sa_family_t(AF_INET),
                sin_port: address.sin_port,
                sin_addr: INADDR_ANY,
                sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
            )
            memcpy(&saddr, &saddr_in, MemoryLayout<sockaddr_in>.size)
            let isBound = bind(newSocket, &saddr, socklen_t(saddr.sa_len))
            if isBound == -1 {
                close(newSocket)
                throw ConnectionError.bindSocketFailed
            }
        }

        // Disable global SIGPIPE handler so that the app doesn't crash
        setNoSigPipe(socket: newSocket)

        // Set up a dispatch source
        let newResponseSource = DispatchSource.makeReadSource(fileDescriptor: newSocket, queue: dispatchQueue)
        let socket = Int32(newResponseSource.handle)

        // Set up cancel handler
        newResponseSource.setCancelHandler {
            shutdown(socket, SHUT_RDWR)
            close(socket)
        }

        // Set up event handler (gets called when data arrives at the UDP socket)
        newResponseSource.setEventHandler { [weak self] in
            self?.handleResponse(socket: socket)
        }

        newResponseSource.resume()
        responseSource = newResponseSource
    }

    private func handleResponse(socket: Int32) {
        var socketAddress = sockaddr_storage()
        var response = [UInt8](repeating: 0, count: 4096)

        let bytesRead = withUnsafeMutablePointer(to: &socketAddress) { pointer -> Int in
            let socketPointer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: sockaddr.self)
            var socketAddressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            return recvfrom(socket, &response, response.count, 0, socketPointer, &socketAddressLength)
        }

        do {
            if bytesRead == 0 {
                throw ConnectionError.receivedEndOfFile
            } else if bytesRead < 0 {
                throw ConnectionError.receiveFailed(code: errno)
            }
            let endpoint = try withUnsafePointer(to: &socketAddress) {
                try self.getEndpointFromSocketAddress(
                    socketAddressPointer: UnsafeRawPointer($0)
                        .bindMemory(to: sockaddr.self, capacity: 1)
                )
            }
            handler?(endpoint.host, endpoint.port, Data(response[0 ..< bytesRead]))
        } catch {
            closeConnection()
            if let error = error as? ConnectionError {
                errorHandler?(error)
            } else {
                errorHandler?(ConnectionError.underlying(error: error))
            }
        }
    }

    /// Prevents crashes when blocking calls are pending and the app is paused (via Home button).
    ///
    /// - Parameter socket: The socket for which the signal should be disabled.
    private func setNoSigPipe(socket: CInt) {
        var no_sig_pipe: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(MemoryLayout<Int32>.size))
    }

    private class func htonsPort(port: in_port_t) -> in_port_t {
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        return isLittleEndian ? _OSSwapInt16(port) : port
    }

    private class func htonsIPv4(ipv4: in_addr_t) -> in_addr_t {
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        return isLittleEndian ? _OSSwapInt32(ipv4) : ipv4
    }

    // MARK: - Helper

    /// Convert a sockaddr structure into an IP address string and port.
    ///
    /// - Parameter socketAddressPointer: socketAddressPointer: Pointer to a socket address.
    /// - Returns: Returns a tuple of the host IP address and the port in the socket address given.
    private func getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer<sockaddr>) throws -> (host: String, port: Int) {
        let socketAddress = UnsafePointer<sockaddr>(socketAddressPointer).pointee

        switch Int32(socketAddress.sa_family) {
        case AF_INET:
            var socketAddressInet = UnsafeRawPointer(socketAddressPointer).load(as: sockaddr_in.self)
            let length = Int(INET_ADDRSTRLEN) + 2
            var buffer = [CChar](repeating: 0, count: length)
            let hostCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet.sin_port).byteSwapped)
            return (String(cString: hostCString!), port)

        case AF_INET6:
            var socketAddressInet6 = UnsafeRawPointer(socketAddressPointer).load(as: sockaddr_in6.self)
            let length = Int(INET6_ADDRSTRLEN) + 2
            var buffer = [CChar](repeating: 0, count: length)
            let hostCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet6.sin6_port).byteSwapped)
            return (String(cString: hostCString!), port)

        default:
            throw ConnectionError.getEndpointFailed(socketAddress: socketAddress)
        }
    }
}
