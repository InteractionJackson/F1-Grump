//
//  Item.swift
//  F1 Grump
//
//  Created by Matt Jackson on 11/09/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
