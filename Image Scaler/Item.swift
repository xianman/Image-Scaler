//
//  Item.swift
//  Image Scaler
//
//  Created by Christian Kittle on 2/9/26.
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
