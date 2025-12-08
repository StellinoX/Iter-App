//
//  PlaceNote.swift
//  app ch3
//
//  Model for personal notes on places
//

import Foundation

struct PlaceNote: Codable, Identifiable {
    var id: Int64 { placeId }
    let placeId: Int64
    var text: String
    var createdAt: Date
    var updatedAt: Date
    
    init(placeId: Int64, text: String) {
        self.placeId = placeId
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func updateText(_ newText: String) {
        self.text = newText
        self.updatedAt = Date()
    }
}
