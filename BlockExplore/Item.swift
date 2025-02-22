//
//  Item.swift
//  BlockExplore
//
//  Created by soso on 2025/2/21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var blockNumber : String
    var blockHash : String
    var transferLog : String
    init(timestamp: Date, blockNumber: String, blockHash: String) {
        self.timestamp = timestamp
        self.blockNumber = blockNumber
        self.blockHash = blockHash
        self.transferLog = ""
    }
}
