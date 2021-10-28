//
//  DataExtract.swift
//

import Foundation

extension Data {
    /// extract n-bytes of data with data[0] containing n.
    mutating func extract() -> Data? {
        guard count > 0 else {
            return nil
        }

        // Define the length of data to return
        let length = Int(self[0])

        // Create a range based on the length of data to return
        let range = 0 ..< length

        // Get a new copy of data
        let subData = subdata(in: range)

        // Mutate data
        removeSubrange(range)

        // Return the new copy of data
        return subData
    }

    /// extract length bytes of data
    mutating func extract(length: Int) -> Data? {
        guard count > 0 else {
            return nil
        }

        // Create a range based on the length of data to return
        let range = 0 ..< length

        // Get a new copy of data
        let subData = subdata(in: range)

        // Mutate data
        removeSubrange(range)

        // Return the new copy of data
        return subData
    }
}
