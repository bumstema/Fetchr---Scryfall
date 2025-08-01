//
//  Item.swift
//  Fetchr - Scryfall
//
//  Created by Arby Bc on 2025-07-31.
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
