import Foundation
import Network

/// This enumeration contains the different types of representations of group addresses in ETS4. 2-level and 3-level style are also available in ETS3, the free group address structure is new to ETS4.
enum KNXGroupAddressStyle_t: String, Codable {
    case ThreeLevel, TwoLevel, Free
}

func KNXSerialNumber(_ serialNumber: Data) -> String {
    let serialStr = serialNumber.hexEncodedString()
    return serialStr.prefix(4) + ":" + serialStr[serialStr.index(serialStr.startIndex, offsetBy: 4)...]
}

func KNXGroupAddress(_ address: UInt16?, groupAddressStyle: KNXGroupAddressStyle_t = .ThreeLevel) -> String {
    if let address = address {
        switch groupAddressStyle {
        case .ThreeLevel: return String(format: "%d/%d/%d", address >> (3 + 8), (address >> 8) & 0x7, address & 0xFF)
        case .TwoLevel: return String(format: "%d/%d", address >> (3 + 8), address & 0x7FF)
        case .Free: return String(format: "%d", address)
        }
    }
    return "?"
}

/// The physical address is a 16-bit value
struct KNXPhysicalAddress: CustomStringConvertible {
    let physicalAddress: UInt16
    init(_ physAddress: UInt16) {
        physicalAddress = physAddress
    }

    var description: String {
        return String(format: "%d.%d.%d", (physicalAddress >> 12) & 0x0F, (physicalAddress >> 8) & 0x0F, physicalAddress & 0xFF)
    }
}

/// The physical address is a 16-bit value
struct MAC: CustomStringConvertible {
    let mac: Data
    init(_ m: Data) {
        assert(m.count == 6)
        mac = m
    }

    var description: String {
        return mac.map { String(format: "%02hhx", $0) }.joined(separator: ":")
    }
}


extension NWEndpoint.Port {
    /// default port for KNXnet/IPx
	public static let KNXnetIPx = NWEndpoint.Port(rawValue: 3671)!
}

extension IPv4Address {
    /// default multicast address for KNXnet/IPx
	public static let KNXnetIPxGroup = IPv4Address("224.0.23.12")!
}

// For binary structures, if not explicitly stated otherwise, the byte order shall be big endian mode (Motorola, non-swapped). For plain text formats, the byte order and formatting shall be according to the related protocol specifications.

// KNXnet/IP Header. The KNXnet/IP telegram contains some additional information compared to the TP1 telegram.

/// KNXnet/IP Service Type Identifier. The KNXnet/IP type identifier indicates which action should be carried out. A detailed list of all the defined addresses can be found in the KNX specifications, volume 3 (System Specifications), part 8 (KNXnet/IP), chapter 1.
enum KNXIPServiceType: UInt16 {
    case
        // 0x0200…0x020f KNXnet/IP Core
        SEARCH_REQUEST = 0x0201,
        SEARCH_RESPONSE = 0x0202,
        DESCRIPTION_REQUEST = 0x0203,
        DESCRIPTION_RESPONSE = 0x0204,
        CONNECT_REQUEST = 0x0205,
        CONNECT_RESPONSE = 0x0206,
        CONNECTIONSTATE_REQUEST = 0x0207,
        CONNECTIONSTATE_RESPONSE = 0x0208,
        DISCONNECT_REQUEST = 0x0209,
        DISCONNECT_RESPONSE = 0x020A,
        SEARCH_REQUEST_EXTENDED = 0x020B,
        SEARCH_RESPONSE_EXTENDED = 0x020C,

        // 0x0310…0x031f KNXnet/IP Device Management
        DEVICE_CONFIGURATION_REQUEST = 0x0310,
        DEVICE_CONFIGURATION_ACK = 0x0311,

        // 0x0420…0x042f KNXnet/IP Tunnelling
        TUNNELLING_REQUEST = 0x0420,
        TUNNELLING_ACK = 0x0421,
        TUNNELLING_FEATURE_GET = 0x0422,
        TUNNELLING_FEATURE_RESPONSE = 0x0423,
        TUNNELLING_FEATURE_SET = 0x0424,
        TUNNELLING_FEATURE_INFO = 0x0425,

        // 0x0530…0x053F KNXnet/IP Routing
        ROUTING_INDICATION = 0x0530,
        ROUTING_LOST_MESSAGE = 0x0531,
        ROUTING_BUSY = 0x0532,
        ROUTING_SYSTEM_BROADCAST = 0x0533,

        // 0x0600…0x06FF KNXnet/IP Remote Logging

        // 0x0740…0x07FF KNXnet/IP Remote Configuration and Diagnosis
        REMOTE_DIAG_REQUEST = 0x0740,
        REMOTE_DIAG_RESPONSE = 0x0741,
        REMOTE_CONFIG_REQUEST = 0x0742,
        REMOTE_RESET_REQUEST = 0x0743,

        // 0x0800…0x08FF KNXnet/IP Object Server

        // 0x0950…0x09FF KNXnet/IP Security
        SECURE_WRAPPER = 0x0950,
        SECURE_SESSION_REQUEST = 0x0951,
        SECURE_SESSION_RESPONSE = 0x0952,
        SECURE_SESSION_AUTHENTICATE = 0x0953,
        SECURE_SESSION_STATUS = 0x0954,
        SECURE_TIMER_NOTIFY = 0x0955
}

enum KNXErrorCodes: UInt8 {
    case
        // The connection state is normal.
        E_NO_ERROR = 0x00,

        // requested host protocol is not supported
        E_HOST_PROTOCOL_TYPE = 0x01,

        // requested protocol version is not supported
        E_VERSION_NOT_SUPPORTED = 0x02,

        // received sequence number is out of order.
        E_SEQUENCE_NUMBER = 0x04,

        // The KNXnet/IP Server device cannot find an active data connection with the specified ID.
        E_CONNECTION_ID = 0x21,

        // The requested connection type is not supported
        E_CONNECTION_TYPE = 0x22,

        // One or more requested connection options are not supported
        E_CONNECTION_OPTION = 0x23,

        // The KNXnet/IP Server device cannot accept the new data connection because its maximum amount of concurrent connections is already occupied.
        E_NO_MORE_CONNECTIONS = 0x24,

        // KNXnet/IP Tunnelling device does not accept connection because the Individual Address is used multiple times
        E_NO_MORE_UNIQUE_CONNECTIONS = 0x25,

        // The KNXnet/IP Server device detects an error concerning the data connection with the specified ID.
        E_DATA_CONNECTION = 0x26,

        // The KNXnet/IP Server device detects an error concerning the KNX subnetwork connection with the specified ID.
        E_KNX_CONNECTION = 0x27,

        // The requested tunnelling layer is not supported by the KNXnet/IP Server device.
        E_TUNNELLING_LAYER = 0x29
}

class KNXIPHeader: CustomDebugStringConvertible {
    let HEADER_SIZE_10: UInt8 = 6 // The header size is always the same. It is transmitted nevertheless as the size may change with further versions of the protocol. It is used to find the start of the total KNXnet/IP frame. The header size is indicated in bytes. The transmitted value is 06hex.
    let KNXNETIP_VERSION_10: UInt8 = 0x10 // The protocol version indicates the status of the KNXnet/IP protocol. It is binary coded and is currently version 1.0. The transmitted value is 10hex.

    var service: KNXIPServiceType?

    func from_data(data: Data) {
        assert(data[0] == HEADER_SIZE_10)
        assert(data[1] == KNXNETIP_VERSION_10)
        service = KNXIPServiceType(rawValue: UInt16(data[2]) << 8 + UInt16(data[3]))!
        // The total length of the KNXnet/IP frame is indicated in bytes in the “Total Length” field. The bytes of the previous fields (Header Length, Protocol Version and Service Type Identifier) are also part of the total length. If the total number of bytes transmitted is greater than 252 bytes, the first “Total Length” byte is set to FF (255). Only in this case the second byte includes additional length information.
        let length = Int(data[4]) << 8 + Int(data[5])
        assert(length >= HEADER_SIZE_10)
    }

    func to_data(bodyLength: Int) -> Data {
        var data: Data = Data()
        data.append(HEADER_SIZE_10)
        data.append(KNXNETIP_VERSION_10)
        data.append(UInt8(service!.rawValue >> 8))
        data.append(UInt8(service!.rawValue & 0xFF))
        let len = bodyLength + Int(HEADER_SIZE_10)
        data.append(UInt8(len >> 8))
        data.append(UInt8(len & 0xFF))
        return data
    }

    var debugDescription: String {
        if let service = service {
            return "\(service)"
        }
        return "Unknown service"
    }
}

// KNX HPAI (Host Protocol Address Information)
// The Host Protocol Address Information structure (HPAI) shall be the address information required to uniquely identify a communication channel on the host protocol. Its size shall vary between different host protocols. For the specific definition of the HPAI consult the host protocol dependent addendums of the KNXnet/IP specification.

class KNXHPAI: CustomDebugStringConvertible {
    let headerLength: UInt8 = 8
    let type: UInt8 = 0x01 // UDP
    var ipv4: IPv4Address
    var ip_port: NWEndpoint.Port

    init() {
        ipv4 = .any
        ip_port = .KNXnetIPx
    }

    func from_data(data: Data) {
        assert(data.count == headerLength)
        assert(data[0] == headerLength)
        assert(data[1] == type)
		ipv4 = IPv4Address(data[2..<6])!
		ip_port = NWEndpoint.Port(rawValue: (UInt16(data[6]) << 8) | (UInt16(data[7]) << 0))!
    }

    func to_data() -> Data {
        var data: Data = Data()
        data.append(headerLength)
        data.append(type)
        data.append(UInt8((ipv4.rawUInt32Value >> 24) & 0xFF))
        data.append(UInt8((ipv4.rawUInt32Value >> 16) & 0xFF))
        data.append(UInt8((ipv4.rawUInt32Value >> 8) & 0xFF))
        data.append(UInt8(ipv4.rawUInt32Value & 0xFF))
        data.append(UInt8((ip_port.rawValue >> 8) & 0xFF))
        data.append(UInt8(ip_port.rawValue & 0xFF))
        return data
    }

    var debugDescription: String {
        "\(ipv4):\(ip_port)"
    }
}

struct KNXMedia: CustomDebugStringConvertible {
    let media: UInt8
    var debugDescription: String {
        var mediums: [String] = [] // bits described in DPT_Media
        if (media & 0x02) == 0x02 {
            mediums.append("TP1")
        }
        if (media & 0x04) == 0x04 {
            mediums.append("PL110")
        }
        if (media & 0x10) == 0x10 {
            mediums.append("RF")
        }
        if (media & 0x20) == 0x20 {
            mediums.append("KNX IP")
        }
        return "medium:\(mediums)"
    }
}

struct KNXDeviceStatus: CustomDebugStringConvertible {
    let deviceStatus: UInt8
    var debugDescription: String {
        var mediums: [String] = []
        if (deviceStatus & 0x01) == 0x01 {
            mediums.append("programmingMode")
        }
        return "deviceStatus:\(mediums)"
    }
}

enum KNXDIBTypeCode: UInt8 {
    case
        DEVICE_INFO = 0x01, // Device information e.g. KNX medium.
        SUPP_SVC_FAMILIES = 0x02, // Service families supported by the device.
        IP_CONFIG = 0x03, // IP configuration
        IP_CUR_CONFIG = 0x04, // current configuration
        KNX_ADDRESSES = 0x05, // KNX addresses
        // 06h to FDh = Reserved for future use
        MFR_DATA = 0xFE // DIB structure for further data defined by device manufacturer.
    // not used = 0xFF
}

enum KNXDIBServiceFamily: UInt8 {
    case
        CORE = 0x02, // Core
        DEVICE_MANAGEMENT = 0x03, // Device Management
        TUNNELING = 0x04, // Tunnelling
        ROUTING = 0x05, // Routing
        REMOTE_LOGGING = 0x06, // Remote Logging
        REMOTE_CONFIGURATION_DIAGNOSIS = 0x07, // Configuration and Diagnosis
        OBJECT_SERVER = 0x08 // Object Server
}

class KNXIPFrame: CustomDebugStringConvertible {
    var header: KNXIPHeader

    init() {
        header = KNXIPHeader()
    }

    public var body: Data {
        return Data()
    }

    func from_data(data: inout Data) {
        header.from_data(data: data.extract()!)
    }

    func frame_to_data() -> Data {
        let body = self.body
        return header.to_data(bodyLength: body.count) + body
    }

    var debugDescription: String {
        return "\(header)"
    }

    static func createFrame(data: Data) throws -> KNXIPFrame? {
        var data = data
        let header = KNXIPHeader()
        header.from_data(data: data)
        let frame: KNXIPFrame
        switch header.service {
        case .SEARCH_REQUEST:
            frame = KNXIPFrame_SEARCH_REQUEST()
        case .SEARCH_RESPONSE:
            frame = KNXIPFrame_SEARCH_RESPONSE()
        case .DESCRIPTION_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .DESCRIPTION_RESPONSE:
            frame = KNXIPFrame_AnyBody()
        case .CONNECT_REQUEST:
            frame = KNXIPFrame_CONNECT_REQUEST()
        case .CONNECT_RESPONSE:
            frame = KNXIPFrame_CONNECT_RESPONSE()
        case .CONNECTIONSTATE_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .CONNECTIONSTATE_RESPONSE:
            frame = KNXIPFrame_AnyBody()
        case .DISCONNECT_REQUEST:
            frame = KNXIPFrame_DISCONNECT_REQUEST()
        case .DISCONNECT_RESPONSE:
            frame = KNXIPFrame_DISCONNECT_RESPONSE()
        case .SEARCH_REQUEST_EXTENDED:
            frame = KNXIPFrame_AnyBody()
        case .SEARCH_RESPONSE_EXTENDED:
            frame = KNXIPFrame_AnyBody()
        case .DEVICE_CONFIGURATION_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .DEVICE_CONFIGURATION_ACK:
            frame = KNXIPFrame_AnyBody()
        case .TUNNELLING_REQUEST:
            frame = KNXIPFrame_TUNNELLING_REQUEST()
        case .TUNNELLING_ACK:
            frame = KNXIPFrame_TUNNELLING_ACK()
        case .TUNNELLING_FEATURE_GET:
            frame = KNXIPFrame_AnyBody()
        case .TUNNELLING_FEATURE_RESPONSE:
            frame = KNXIPFrame_AnyBody()
        case .TUNNELLING_FEATURE_SET:
            frame = KNXIPFrame_AnyBody()
        case .TUNNELLING_FEATURE_INFO:
            frame = KNXIPFrame_AnyBody()
        case .ROUTING_INDICATION:
            frame = KNXIPFrame_AnyBody()
        case .ROUTING_LOST_MESSAGE:
            frame = KNXIPFrame_AnyBody()
        case .ROUTING_BUSY:
            frame = KNXIPFrame_AnyBody()
        case .ROUTING_SYSTEM_BROADCAST:
            frame = KNXIPFrame_AnyBody()
        case .REMOTE_DIAG_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .REMOTE_DIAG_RESPONSE:
            frame = KNXIPFrame_AnyBody()
        case .REMOTE_CONFIG_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .REMOTE_RESET_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_WRAPPER:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_SESSION_REQUEST:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_SESSION_RESPONSE:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_SESSION_AUTHENTICATE:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_SESSION_STATUS:
            frame = KNXIPFrame_AnyBody()
        case .SECURE_TIMER_NOTIFY:
            frame = KNXIPFrame_AnyBody()
        case .none:
            return nil
        }
        frame.from_data(data: &data)
        return frame
    }
}

class KNXIPFrame_AnyBody: KNXIPFrame {
    private var _body: Data

    override init() {
        _body = Data()
        super.init()
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        _body = data
    }

    override public var body: Data {
        return _body
    }

    override var debugDescription: String {
        super.debugDescription + " : \(String(describing: _body.hexEncodedString()))"
    }
}

class KNXIPFrameHapi: KNXIPFrame {
    var hpai: KNXHPAI

    override init() {
        hpai = KNXHPAI()
        super.init()
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        hpai.from_data(data: data.extract()!)
    }

    override public var body: Data {
        return super.body + hpai.to_data()
    }

    override var debugDescription: String {
        super.debugDescription + " \(String(describing: hpai))"
    }
}

class KNXIPFrame_SEARCH_REQUEST: KNXIPFrameHapi {
    override init() {
        super.init()
        header.service = .SEARCH_REQUEST
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
    }
}

protocol KNXDib: CustomDebugStringConvertible {
    init(data: Data)
}

class KNXDIB_DEVICE_INFO: KNXDib {
    var knxMedium: KNXMedia!
    var deviceStatus: KNXDeviceStatus!
    var physicalAddress: KNXPhysicalAddress!
    var projectInstallationIdentifier: UInt16!
    var serialNumber: String!
    var multcastAddress: IPv4Address!
    var MACAddress: MAC!
    var name: String!

    required init(data: Data) {
        knxMedium = KNXMedia(media: data[2])
        deviceStatus = KNXDeviceStatus(deviceStatus: data[3])
        physicalAddress = KNXPhysicalAddress((UInt16(data[4]) << 8) | (UInt16(data[5]) << 0))
        projectInstallationIdentifier = (UInt16(data[6]) << 8) | (UInt16(data[7]) << 0)
        serialNumber = KNXSerialNumber(data[8 ..< 14])
        multcastAddress = IPv4Address(data[14..<18])
        MACAddress = MAC(data[18 ..< 24])
        name = String(decoding: data[24 ..< data[0]], as: UTF8.self).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(["\0"])))
    }

    var debugDescription: String {
        "DEVICE_INFO: \(knxMedium!) \(deviceStatus!) phys:\(physicalAddress!) sn:\(serialNumber!) IP:\(multcastAddress!) MAC:\(MACAddress!) name:\"\(name!)\""
    }
}

class KNXDIB_SUPP_SVC_FAMILIES: KNXDib {
    var familyVersions: [KNXDIBServiceFamily: Int]

    required init(data: Data) {
        familyVersions = [:]
        for index in stride(from: 2, to: data.count, by: 2) {
            familyVersions[KNXDIBServiceFamily(rawValue: data[index])!] = Int(data[index + 1])
        }
    }

    var debugDescription: String {
        "SUPP_SVC_FAMILIES: \(String(describing: familyVersions))"
    }
}

class KNXIPFrame_SEARCH_RESPONSE: KNXIPFrameHapi {
    var dibs: [KNXDib]
    var name: String?

    override init() {
        dibs = []
        name = nil
        super.init()
        header.service = .SEARCH_RESPONSE
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        dibs = []

        // then parse the DIB headers
        while let sdata = data.extract() {
            let dibType = KNXDIBTypeCode(rawValue: sdata[1])
            switch dibType {
            case .DEVICE_INFO:
                let deviceInfo = KNXDIB_DEVICE_INFO(data: sdata)
                name = deviceInfo.name
                dibs.append(deviceInfo)
            case .SUPP_SVC_FAMILIES:
                dibs.append(KNXDIB_SUPP_SVC_FAMILIES(data: sdata))
                break
            case .IP_CONFIG:
                break
            case .IP_CUR_CONFIG:
                break
            case .KNX_ADDRESSES:
                break
            case .MFR_DATA:
                break
            case .none:
                break
            }
        }
    }

    override var debugDescription: String {
        var str = ""
        for dib in dibs {
            str += "\n• " + dib.debugDescription
        }
        return super.debugDescription + str
    }
}

enum KNXConnectRequestType: UInt8 {
    case
        DEVICE_MGMT_CONNECTION = 0x03, // Data connection used to configure a KNXnet/IP device.
        TUNNEL_CONNECTION = 0x04, // Data connection used to forward KNX telegrams between two KNXnet/IP devices.
        REMLOG_CONNECTION = 0x06, // Data connection used for configuration and data transfer with a remote logging server.
        REMCONF_CONNECTION = 0x07, // Data connection used for data transfer with a remote configuration server.
        OBJSVR_CONNECTION = 0x08 // Data connection used for configuration and data transfer with an Object Server in a KNXnet/IP device.
}

enum KNXTunnelLayer: UInt8 {
    case
        TUNNEL_LINKLAYER = 0x02, // Establish a Data Link Layer tunnel to the KNX network.
        TUNNEL_RAW = 0x04, // Establish a raw tunnel to the KNX network.
        TUNNEL_BUSMONITOR = 0x80 // Establish a Busmonitor tunnel to the KNX network.
}

class KNXIPFrame_CONNECT_REQUEST: KNXIPFrame {
    var controlEndpoint: KNXHPAI
    var dataEndpoint: KNXHPAI
    var criType: KNXConnectRequestType
    var criKNXLayer: KNXTunnelLayer

    override init() {
        controlEndpoint = KNXHPAI()
        dataEndpoint = KNXHPAI()
        criType = .DEVICE_MGMT_CONNECTION
        criKNXLayer = .TUNNEL_LINKLAYER
        super.init()
        header.service = .CONNECT_REQUEST
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        controlEndpoint.from_data(data: data.extract()!)
        dataEndpoint.from_data(data: data.extract()!)
        // Connection Request Information (CRI)
        if let cri = data.extract() {
            assert(cri[0] == 4)
            criType = KNXConnectRequestType(rawValue: cri[1])!
            criKNXLayer = KNXTunnelLayer(rawValue: cri[2])!
        }
    }

    override public var body: Data {
        let cri = Data([4, criType.rawValue, criKNXLayer.rawValue, 0])
        return super.body + controlEndpoint.to_data() + dataEndpoint.to_data() + cri
    }

    override var debugDescription: String {
        super.debugDescription + " CTRL:\(String(describing: controlEndpoint)) DATA:\(String(describing: dataEndpoint)) \(criType), \(criKNXLayer)"
    }
}

class KNXIPFrame_CONNECT_RESPONSE: KNXIPFrame {
    var communicationChannelID: UInt8
    var status: KNXErrorCodes
    var dataEndpoint: KNXHPAI
    var requestType: KNXConnectRequestType
    var KNXIndividualAddress: KNXPhysicalAddress

    override init() {
        communicationChannelID = 0
        status = .E_NO_ERROR
        dataEndpoint = KNXHPAI()
        requestType = .TUNNEL_CONNECTION
        KNXIndividualAddress = KNXPhysicalAddress(0)
        super.init()
        header.service = .CONNECT_RESPONSE
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        if let d = data.extract(length: 2) {
            communicationChannelID = d[0]
            status = KNXErrorCodes(rawValue: d[1]) ?? .E_NO_ERROR
        }
        dataEndpoint.from_data(data: data.extract()!)
        let crd = data.extract()!
        assert(crd[0] == 4)
        requestType = KNXConnectRequestType(rawValue: crd[1])!
        KNXIndividualAddress = KNXPhysicalAddress((UInt16(crd[2]) << 8) + UInt16(crd[3]))
    }

    override public var body: Data {
        var data = super.body
        data.append(communicationChannelID)
        data.append(status.rawValue)
        data.append(dataEndpoint.to_data())
        data.append(4) // size of CRD
        data.append(requestType.rawValue)
        data.append(UInt8(KNXIndividualAddress.physicalAddress >> 8))
        data.append(UInt8(KNXIndividualAddress.physicalAddress))
        return data
    }

    override var debugDescription: String {
        return super.debugDescription + " CH:\(communicationChannelID) STATUS:\(status) DATA:\(dataEndpoint) \(requestType):\(KNXIndividualAddress)"
    }
}

class KNXIPFrame_DISCONNECT_REQUEST: KNXIPFrame {
    var communicationChannelID: UInt8
    var controlEndpoint: KNXHPAI

    override init() {
        communicationChannelID = 0
        controlEndpoint = KNXHPAI()
        super.init()
        header.service = .DISCONNECT_REQUEST
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        if let d = data.extract(length: 2) {
            communicationChannelID = d[0]
        }
        controlEndpoint.from_data(data: data.extract()!)
    }

    override public var body: Data {
        var data = super.body
        data.append(communicationChannelID)
        data.append(0)
        return data + controlEndpoint.to_data()
    }

    override var debugDescription: String {
        super.debugDescription + " CH:\(communicationChannelID) CTRL:\(String(describing: controlEndpoint))"
    }
}

class KNXIPFrame_DISCONNECT_RESPONSE: KNXIPFrame {
    var communicationChannelID: UInt8
    var status: KNXErrorCodes

    override init() {
        communicationChannelID = 0
        status = .E_NO_ERROR
        super.init()
        header.service = .DISCONNECT_RESPONSE
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        if let d = data.extract(length: 2) {
            communicationChannelID = d[0]
            status = KNXErrorCodes(rawValue: d[1]) ?? .E_NO_ERROR
        }
    }

    override public var body: Data {
        var data = super.body
        data.append(communicationChannelID)
        data.append(status.rawValue)
        return data
    }

    override var debugDescription: String {
        super.debugDescription + " CH:\(communicationChannelID) STATUS:\(status)"
    }
}

class KNXIPFrame_TUNNELLING_REQUEST: KNXIPFrame {
    var communicationChannelID: UInt8
    var sequenceCounter: UInt8
    var cEMI: CEMIFrame

    override init() {
        communicationChannelID = 0
        sequenceCounter = 0
        cEMI = CEMIFrame()
        super.init()
        header.service = .TUNNELLING_REQUEST
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        if let d = data.extract(length: 4) {
            assert(d[0] == 4)
            communicationChannelID = d[1]
            sequenceCounter = d[2]
        }
        cEMI.from_data(data: &data)
    }

    override public var body: Data {
        var data = super.body
        data.append(4)
        data.append(communicationChannelID)
        data.append(sequenceCounter)
        data.append(0)
        data.append(cEMI.body)
        return data
    }

    override var debugDescription: String {
        super.debugDescription + " CH:\(communicationChannelID) #:\(sequenceCounter) cEMI(\(cEMI.debugDescription))"
    }
}

class KNXIPFrame_TUNNELLING_ACK: KNXIPFrame {
    var communicationChannelID: UInt8
    var sequenceCounter: UInt8
    var status: KNXErrorCodes

    override init() {
        communicationChannelID = 0
        sequenceCounter = 0
        status = .E_NO_ERROR
        super.init()
        header.service = .TUNNELLING_ACK
    }

    override func from_data(data: inout Data) {
        super.from_data(data: &data)
        if let d = data.extract(length: 4) {
            assert(d[0] == 4)
            communicationChannelID = d[1]
            sequenceCounter = d[2]
            status = KNXErrorCodes(rawValue: d[3]) ?? .E_NO_ERROR
        }
    }

    override public var body: Data {
        var data = super.body
        data.append(4)
        data.append(communicationChannelID)
        data.append(sequenceCounter)
        data.append(status.rawValue)
        return data
    }

    override var debugDescription: String {
        super.debugDescription + " CH:\(communicationChannelID) #:\(sequenceCounter) status:\(status)"
    }
}

enum CEMIMessageCode: UInt8 {
    case
        // FROM NETWORK LAYER TO DATA LINK LAYER
        L_RAW_REQ = 0x10,
        L_DATA_REQ = 0x11, // Data Service.
        // Primitive used for transmitting a data frame
        L_POLL_DATA_REQ = 0x13, // Poll Data Service

        // FROM DATA LINK LAYER TO NETWORK LAYER
        L_POLL_DATA_CON = 0x25, // Poll Data Service
        L_DATA_IND = 0x29, // Data Service.
        // Primitive used for receiving a data frame
        L_BUSMON_IND = 0x2B, // Bus Monitor Service
        L_RAW_IND = 0x2D,
        L_DATA_CON = 0x2E, // Data Service.
        // Primitive used for local confirmation that a frame was sent (does not indicate a successful receive though)
        L_RAW_CON = 0x2F
}

/// Enum class for KNX/IP CEMI Flags.
struct CEMIFlags {
    // Bit 1/7
    //  FRAME_TYPE_EXTENDED = 0x0000
    //  FRAME_TYPE_STANDARD = 0x8000
    enum FRAME_TYPE {
        case EXTENDED, STANDARD
    }

    var frameType: FRAME_TYPE

    // Bit 1/6 - Reserved

    // Bit 1/5
    // Repeat in case of an error (REPEAT = 0x0000, DO_NOT_REPEAT = 0x2000)
    var repeatTransmission: Bool

    // Bit 1/4
    //  SYSTEM_BROADCAST = 0x0000,
    //  BROADCAST = 0x1000,
    enum BROADCAST {
        case SYSTEM_BROADCAST, BROADCAST
    }

    var broadcast: BROADCAST

    // Bit 1/3+2
    //  PRIORITY_SYSTE = 0x0000,
    //  PRIORITY_NORMAL = 0x0400,
    //  PRIORITY_URGENT = 0x0800,
    //  PRIORITY_LOW = 0x0C00,
    enum PRIORITY {
        case SYSTEM, NORMAL, URGENT, LOW
    }

    var priority: PRIORITY

    // Bit 1/1
    //  NO_ACK_REQUESTED = 0x0000,
    //  ACK_REQUESTED = 0x0200,
    var ackRequested: Bool

    // Bit 1/0
    //  CONFIRM_NO_ERROR = 0x0000,
    //  CONFIRM_ERROR = 0x0100,
    var confirmError: Bool

    // Bit 0/7
    //  DESTINATION_INDIVIDUAL_ADDRESS = 0x0000,
    //  DESTINATION_GROUP_ADDRESS = 0x0080,
    enum DESTINATION {
        case INDIVIDUAL_ADDRESS, GROUP_ADDRESS
    }

    var destination: DESTINATION

    // Bit 0/6+5+4
    //  HOP_COUNT_NO = 0x0070,
    //  HOP_COUNT_1ST = 0x0060,
    var hops: Int

    // Bit 0/3+2+1+0
    //  STANDARD_FRAME_FORMAT = 0x0000,
    //  EXTENDED_FRAME_FORMAT = 0x0001
    enum FRAME_FORMAT {
        case STANDARD_FRAME_FORMAT, EXTENDED_FRAME_FORMAT, ILLEGAL
    }

    var frameFormat: FRAME_FORMAT

    init(rawValue: UInt16) {
        frameType = (rawValue & 0x8000) == 0x8000 ? .STANDARD : .EXTENDED
        repeatTransmission = (rawValue & 0x2000) == 0x2000
        broadcast = (rawValue & 0x1000) == 0x1000 ? .SYSTEM_BROADCAST : .BROADCAST
//      if (rawValue & 0x0C00) == 0x000
        priority = .SYSTEM
        if (rawValue & 0x0C00) == 0x400 {
            priority = .NORMAL
        } else if (rawValue & 0x0C00) == 0x800 {
            priority = .URGENT
        } else if (rawValue & 0x0C00) == 0xC00 {
            priority = .LOW
        }
        ackRequested = (rawValue & 0x0200) == 0x0200
        confirmError = (rawValue & 0x0100) == 0x0100
        destination = (rawValue & 0x0080) == 0x0080 ? .GROUP_ADDRESS : .INDIVIDUAL_ADDRESS
        hops = Int((rawValue >> 4) & 7) ^ 7
        switch rawValue & 0xF {
        case 0: frameFormat = .STANDARD_FRAME_FORMAT
        case 1: frameFormat = .EXTENDED_FRAME_FORMAT
        default:
            frameFormat = .ILLEGAL
        }
    }
}

let PDUCommands: [UInt32: String] = [
    0x03FF0000: "A_GroupValue_Read",
    0x03C00040: "A_GroupValue_Response",
    0x03C00080: "A_GroupValue_Write",
    0x03FF00C0: "A_IndividualAddress_Write",
    0x03FF0100: "A_IndividualAddress_Read",
    0x03FF0140: "A_IndividualAddress_Response",
    0x03C00180: "A_ADC_Read",
    0x03C001C0: "A_ADC_Response",
    0x03FF01C8: "A_SystemNetworkParameter_Read",
    0x03FF01C9: "A_SystemNetworkParameter_Response",
    0x03FF01CA: "A_SystemNetworkParameter_Write",
    0x03FF01CB: "planned for future system broadcast service",
    0x03C00200: "A_Memory_Read",
    0x03C00240: "A_Memory_Response",
    0x03C00280: "A_Memory_Write",
    0x03FF02C0: "A_UserMemory_Read",
    0x03FF02C1: "A_UserMemory_Response",
    0x03FF02C2: "A_UserMemory_Write",
    0x03FF02C4: "A_UserMemoryBit_Write",
    0x03FF02C5: "A_UserManufacturerInfo_Read",
    0x03FF02C6: "A_UserManufacturerInfo_Response",
    0x03FF02C7: "A_FunctionPropertyCommand",
    0x03FF02C8: "A_FunctionPropertyState_Read",
    0x03FF02C9: "A_FunctionPropertyState_Response",
    0x03FF0300: "A_DeviceDescriptor_Read",
    0x03FF0340: "A_DeviceDescriptor_Response",
    0x03FF0380: "A_Restart",
    0x03FF03C0: "A_Open_Routing_Table_Req",
    0x03FF03C1: "A_Read_Routing_Table_Req",
    0x03FF03C2: "A_Read_Routing_Table_Res",
    0x03FF03C3: "A_Write_Routing_Table_Req",
    0x03FF03C8: "A_Read_Router_Memory_Req",
    0x03FF03C9: "A_Read_Router_Memory_Res",
    0x03FF03CA: "A_Write_Router_Memory_Req",
    0x03FF03CD: "A_Read_Router_Status_Req",
    0x03FF03CE: "A_Read_Router_Status_Res",
]

class CEMIFrame: CustomDebugStringConvertible {
    var messageCode: CEMIMessageCode
    var addil: Int
    var flags: CEMIFlags
    var src_addr: KNXPhysicalAddress
    var dst_addr: UInt16
    var mpdu_len: UInt8
    var packageData: String

    init() {
        messageCode = .L_DATA_IND
        addil = 0
        flags = CEMIFlags(rawValue: 0)
        src_addr = KNXPhysicalAddress(0)
        dst_addr = 0
        mpdu_len = 0
        packageData = ""
    }

    func from_data(data: inout Data) {
        assert(data.count >= 11)
        messageCode = CEMIMessageCode(rawValue: data[0])!
        assert(messageCode == .L_DATA_IND || messageCode == .L_DATA_REQ || messageCode == .L_DATA_CON)
        addil = Int(data[1])
        if let d = data.extract(length: 9 + addil) {
            flags = CEMIFlags(rawValue: (UInt16(d[2 + addil]) << 8) + UInt16(d[3 + addil]))
            src_addr = KNXPhysicalAddress((UInt16(d[4 + addil]) << 8) + UInt16(d[5 + addil]))
            if flags.destination == .GROUP_ADDRESS {
                dst_addr = (UInt16(d[6 + addil]) << 8) + UInt16(d[7 + addil])
            } else {
                dst_addr = (UInt16(d[6 + addil]) << 8) + UInt16(d[7 + addil])
            }
            mpdu_len = d[8 + addil]
        }
        assert((mpdu_len + 1) == data.count)
        if let d = data.extract(length: 2) {
            let tcpi_apci = (UInt16(d[0]) << 8) + UInt16(d[1])
            packageData = String(format: "%02x:%d:", tcpi_apci >> 6, tcpi_apci & 0x3F) + data.hexEncodedString()
            for (maskValue, pduCommandStr) in PDUCommands {
                let mask = UInt16(maskValue >> 16)
                let value = UInt16(maskValue & 0xFFFF)
                if (tcpi_apci & mask) == value {
                    packageData = pduCommandStr + ":"
                    if flags.destination == .GROUP_ADDRESS {
                        let groupAddress = KNXGroupAddress(dst_addr)
                        if data.count == 0 {
                            data = Data([UInt8((tcpi_apci & ~mask) & 0x3FF)])
                        }
                        let dpt: KNXDPT = groupAddress_to_dpt_conversionTable[groupAddress] ?? .DPT_1_xxx
                        packageData += convert_from_knx(data: data, dpt: dpt)
                    } else {
                        packageData += data.hexEncodedString()
                    }
                    break
                }
            }
        }
    }

    public var body: Data {
        var data = Data()
        data.append(messageCode.rawValue)
        return data
    }

    var debugDescription: String {
//        "CODE:\(messageCode) flags:\(flags) SRC:\(src_addr) DST:\(GroupAddress(dst_addr))"
        if flags.destination == .GROUP_ADDRESS {
            return "CODE:\(messageCode) SRC:\(src_addr) DST:\(KNXGroupAddress(dst_addr)) \(packageData)"
        } else {
            return "CODE:\(messageCode) SRC:\(src_addr) DST:\(KNXPhysicalAddress(dst_addr)) \(packageData)"
        }
    }
}
