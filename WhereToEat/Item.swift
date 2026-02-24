//
//  Item.swift
//  WhereToEat
//
//  Created by YIMING GE on 2/23/26.
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
