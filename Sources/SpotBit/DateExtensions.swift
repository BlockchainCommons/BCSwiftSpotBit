//
//  File.swift
//  
//
//  Created by Wolf McNally on 1/13/22.
//

import Foundation

extension Date {
    init(millisSince1970: Double) {
        self.init(timeIntervalSince1970: millisSince1970 / 1000)
    }
    
    var millisSince1970: Double {
        return timeIntervalSince1970 * 1000
    }
}
