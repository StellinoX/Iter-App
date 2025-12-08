//
//  Trip.swift
//  app ch3
//
//  Model for a planned trip with dates and daily itinerary
//

import Foundation

struct Trip: Codable, Identifiable {
    let id: UUID
    var cityName: String
    var startDate: Date
    var endDate: Date
    var days: [TripDay]
    var createdAt: Date
    
    var numberOfDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    init(cityName: String, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.cityName = cityName
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        
        // Initialize empty days
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day! + 1)
        self.days = (0..<dayCount).map { index in
            let date = Calendar.current.date(byAdding: .day, value: index, to: startDate)!
            return TripDay(dayNumber: index + 1, date: date)
        }
    }
}

struct TripDay: Codable, Identifiable {
    let id: UUID
    let dayNumber: Int
    let date: Date
    var activities: [TripActivity]
    var lunchSuggestions: MealSuggestion?
    var dinnerSuggestions: MealSuggestion?
    
    init(dayNumber: Int, date: Date) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.date = date
        self.activities = []
        self.lunchSuggestions = nil
        self.dinnerSuggestions = nil
    }
}

struct MealSuggestion: Codable {
    var afterActivityIndex: Int  // Show after this activity
    var restaurants: [RestaurantSuggestion]
    var mealType: MealType
    
    enum MealType: String, Codable {
        case lunch = "Lunch"
        case dinner = "Dinner"
        
        var emoji: String {
            switch self {
            case .lunch: return "🍝"
            case .dinner: return "🍷"
            }
        }
        
        var suggestedTime: String {
            switch self {
            case .lunch: return "~12:30"
            case .dinner: return "~20:00"
            }
        }
    }
}

struct TripActivity: Codable, Identifiable {
    let id: UUID
    var placeId: Int64?
    var placeName: String
    var startTime: String // e.g., "09:00"
    var duration: String // e.g., "2h"
    var transportMode: TransportMode?
    var transportDuration: String? // e.g., "15 min"
    var transportDetails: String? // e.g., "Bus 64"
    var notes: String?
    
    init(placeName: String, startTime: String = "", duration: String = "1h") {
        self.id = UUID()
        self.placeName = placeName
        self.startTime = startTime
        self.duration = duration
    }
}

enum TransportMode: String, Codable, CaseIterable {
    case walking = "walking"
    case bus = "bus"
    case metro = "metro"
    case taxi = "taxi"
    case car = "car"
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .bus: return "bus.fill"
        case .metro: return "tram.fill"
        case .taxi: return "car.fill"
        case .car: return "car.side.fill"
        }
    }
}
