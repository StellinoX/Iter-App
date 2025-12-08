//
//  Itinerary.swift
//  app ch3
//
//  Model for trip itineraries with multiple stops
//

import Foundation

struct Itinerary: Codable, Identifiable {
    let id: UUID
    var name: String
    var placeIds: [Int64]
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, placeIds: [Int64] = []) {
        self.id = UUID()
        self.name = name
        self.placeIds = placeIds
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func addPlace(_ placeId: Int64) {
        if !placeIds.contains(placeId) {
            placeIds.append(placeId)
            updatedAt = Date()
        }
    }
    
    mutating func removePlace(_ placeId: Int64) {
        placeIds.removeAll { $0 == placeId }
        updatedAt = Date()
    }
    
    mutating func reorderPlaces(_ newOrder: [Int64]) {
        placeIds = newOrder
        updatedAt = Date()
    }
}
