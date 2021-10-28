//
//  IPv4AddressExtension.swift
//

import Foundation
import Network

extension IPv4Address {
    /// Convert an IPv4Address into a big-endian UInt32
    public var rawUInt32Value: UInt32 {
        return UInt32(bigEndian: rawValue.withUnsafeBytes { $0.load(as: UInt32.self) })
    }
}
