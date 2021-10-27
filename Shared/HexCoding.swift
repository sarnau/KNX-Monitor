//
//  HexCoding.swift
//  UDPSendTest
//
//  Created by Markus Fritze on 05.10.21.
//

import Foundation

extension String {
    enum ExtendedEncoding {
        case hexadecimal
    }

    /// decode a hex-string into Data
    func data(using encoding: ExtendedEncoding) -> Data? {
        let hexStr = dropFirst(hasPrefix("0x") ? 2 : 0)

        guard hexStr.count % 2 == 0 else { return nil }

        var newData = Data(capacity: hexStr.count / 2)

        var indexIsEven = true
        for i in hexStr.indices {
            if indexIsEven {
                let byteRange = i ... hexStr.index(after: i)
                guard let byte = UInt8(hexStr[byteRange], radix: 16) else { return nil }
                newData.append(byte)
            }
            indexIsEven.toggle()
        }
        return newData
    }
}

extension Data {
    /// convert data into a ASCII-String of hex numbers
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
