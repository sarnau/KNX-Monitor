//
//  ContentView.swift
//  Shared
//
//  Created by Markus Fritze on 03.10.21.
//

import Network
import SwiftUI

class KNXServerManager: ObservableObject {
    var broadcastConnection: UDPBroadcastConnection!
    var serverIndex = 0
    @Published var serverList: [Int: KNXIPFrame_SEARCH_RESPONSE] = [:]

    func searchServers() {
        do {
            serverList = [:]
            serverIndex = 0
            broadcastConnection = try UDPBroadcastConnection(
                mcast_port: 3671,
                mcast_group: in_addr_t(IPv4Address("224.0.23.12")!.rawUInt32Value),
                bindIt: true,
                handler: { (_: String, _: Int, response: Data) -> Void in
                    do {
                        if let knxFrame = try KNXIPFrame.createFrame(data: response) {
                            // print("\n" + knxFrame.debugDescription)
                            if let response = knxFrame as? KNXIPFrame_SEARCH_RESPONSE {
                                self.serverList[self.serverIndex] = response
                                self.serverIndex += 1
                            }
                        }
                    } catch {
                        print("KNX decode error: \(error) for \(response.hexEncodedString())")
                    }
                },
                errorHandler: { error in
                    print(error)
                })
        } catch {
            if let connectionError = error as? UDPBroadcastConnection.ConnectionError {
                print(connectionError)
            } else {
                print("Error: \(error)")
            }
        }

        do {
            let searchRequest = KNXIPFrame_SEARCH_REQUEST()
            try broadcastConnection.sendBroadcast(searchRequest.frame_to_data())
            print("Sent: '\(searchRequest)'")
        } catch {
            if let connectionError = error as? UDPBroadcastConnection.ConnectionError {
                print(connectionError)
            } else {
                print("Error: \(error)")
            }
        }
    }
}

struct ContentView: View {
    let localPort: UInt16 = 57923
    @State var udp: UDPClient?
    @State var monitor: NWPathMonitor?
    @ObservedObject var serverManager = KNXServerManager()
    @State var serverChoice = 0
    @State var localHostIP: String = ""
    @State var connectChannelID: UInt8 = 0

    var body: some View {
        VStack {
            Button("Search") {
                serverManager.searchServers()
            }
            Picker("Options", selection: $serverChoice) {
                ForEach(Array(serverManager.serverList.keys.enumerated()), id: \.element) { index, _ in
                    if let frame = serverManager.serverList[index] {
                        Text(frame.name! + " (\(frame.hpai.ip_addr):\(frame.hpai.ip_port))")
                            .tag(index)
                    }
                }
            }.pickerStyle(MenuPickerStyle())
            Button("Open") {
                // find out our local Wifi IP address, which we need inside a KNX package
                monitor = NWPathMonitor(requiredInterfaceType: .wifi)
                monitor?.pathUpdateHandler = { (path: NWPath) in
                    guard path.status == .satisfied else { return }
                    localHostIP = try! getInterfaceIPAddress(interfaceName: path.availableInterfaces.first!.name)
                    print("LOCAL IP \(localHostIP):\(localPort)")
                    if let frame = serverManager.serverList[serverChoice] {
                        print((frame.name!) + " (\(frame.hpai.ip_addr):\(frame.hpai.ip_port))")
                        udp = UDPClient(host: "\(frame.hpai.ip_addr)", port: frame.hpai.ip_port, localHost: localHostIP, localPort: localPort)
                        udp!.start(on: .main)
                    }
                }
                monitor?.start(queue: .main)
            }.disabled(udp != nil)

            Button("Close") {
                monitor = nil
                udp!.stop()
                udp = nil
            }.disabled(udp == nil)

            Button("Connect") {
                let frame = KNXIPFrame_CONNECT_REQUEST()
				frame.controlEndpoint.ip_addr = IPv4Address(localHostIP)!
                frame.controlEndpoint.ip_port = localPort
				frame.dataEndpoint.ip_addr = IPv4Address(localHostIP)!
                frame.dataEndpoint.ip_port = localPort
                frame.criType = .TUNNEL_CONNECTION
                let data = frame.frame_to_data()
                if let knxFrame = try! KNXIPFrame.createFrame(data: data) {
                    print(knxFrame.debugDescription)
                } else {
                    print("SEND UNKNOWN FRAME: \(data)")
                }
                udp?.onReceiveData = { (data: Data) in
                    if let knxFrame = try! KNXIPFrame.createFrame(data: data) {
                        print(knxFrame.debugDescription)
                        if let response = knxFrame as? KNXIPFrame_CONNECT_RESPONSE {
                            connectChannelID = response.communicationChannelID
                        } else if let response = knxFrame as? KNXIPFrame_TUNNELLING_REQUEST {
                            let reply = KNXIPFrame_TUNNELLING_ACK()
                            reply.communicationChannelID = response.communicationChannelID
                            reply.sequenceCounter = response.sequenceCounter
                            reply.status = .E_NO_ERROR
//                            if let knxFrame = try! KNXIPFrame.createFrame(data: reply.frame_to_data()) {
//                                print(knxFrame.debugDescription)
//                            }
                            udp?.send(reply.frame_to_data())
                        }
                    } else {
                        print("RECEIVED UNKNOWN FRAME: \(data.hexEncodedString())")
                    }
                }
                udp?.send(data)
            }.disabled(udp == nil || connectChannelID != 0)

            Button("Disconnect") {
                let frame = KNXIPFrame_DISCONNECT_REQUEST()
                frame.communicationChannelID = connectChannelID
                connectChannelID = 0
                frame.controlEndpoint.ip_addr = IPv4Address(localHostIP)!
                frame.controlEndpoint.ip_port = localPort
                let data = frame.frame_to_data()
//                print("SEND \(data)")
                if let knxFrame = try! KNXIPFrame.createFrame(data: data) {
                    print(knxFrame.debugDescription)
                }
                udp?.onReceiveData = { (data: Data) in
//                    print("RECEIVE \(data.hexEncodedString())")
                    if let knxFrame = try! KNXIPFrame.createFrame(data: data) {
                        print(knxFrame.debugDescription)
                    }
                }
                udp?.send(data)
            }.disabled(udp == nil || connectChannelID == 0)
        }.padding()
    }
}
