//
//  DirectionsService.swift
//  app ch3
//
//  Service for getting real route/directions data using Apple MapKit (FREE!)
//

import Foundation
import MapKit
import CoreLocation
import UIKit

struct RouteInfo {
    let distance: String      // e.g. "1.2 km"
    let duration: String      // e.g. "15 min"
    let mode: String          // walking, transit, driving
    let polyline: MKPolyline? // For drawing on map
    let steps: [RouteStep]
}

struct RouteStep {
    let instruction: String   // e.g. "Walk to Via Roma"
    let distance: String
}

class DirectionsService {
    
    /// Get walking route between two coordinates
    func getWalkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> RouteInfo? {
        return await getRoute(from: origin, to: destination, transportType: .walking)
    }
    
    /// Get transit route between two coordinates
    func getTransitRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> RouteInfo? {
        return await getRoute(from: origin, to: destination, transportType: .transit)
    }
    
    /// Create MKMapItem from coordinate using iOS 26+ API
    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return MKMapItem(location: location, address: nil)
    }
    
    /// Get route between two coordinates
    func getRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .walking) async -> RouteInfo? {
        
        let request = MKDirections.Request()
        request.source = mapItem(for: origin)
        request.destination = mapItem(for: destination)
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                print("❌ DirectionsService: No routes found")
                return nil
            }
            
            // Format distance
            let distanceKm = route.distance / 1000
            let distanceStr = distanceKm < 1 
                ? "\(Int(route.distance)) m" 
                : String(format: "%.1f km", distanceKm)
            
            // Format duration
            let minutes = Int(route.expectedTravelTime / 60)
            let durationStr = minutes < 60 
                ? "\(minutes) min" 
                : "\(minutes / 60)h \(minutes % 60)min"
            
            // Get steps
            var steps: [RouteStep] = []
            for step in route.steps.prefix(5) where !step.instructions.isEmpty {
                let stepDistance = step.distance < 1000 
                    ? "\(Int(step.distance)) m" 
                    : String(format: "%.1f km", step.distance / 1000)
                steps.append(RouteStep(instruction: step.instructions, distance: stepDistance))
            }
            
            let modeStr = transportType == .walking ? "walking" : 
                         transportType == .transit ? "transit" : "driving"
            
            print("📍 Route: \(distanceStr), \(durationStr) (\(modeStr))")
            
            return RouteInfo(
                distance: distanceStr,
                duration: durationStr,
                mode: modeStr,
                polyline: route.polyline,
                steps: steps
            )
            
        } catch {
            print("❌ DirectionsService: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get route from address string to coordinate using MKLocalSearch
    func getRoute(fromAddress: String, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .walking) async -> RouteInfo? {
        
        // Use MKLocalSearch instead of CLGeocoder
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = fromAddress
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                print("❌ DirectionsService: Could not find address")
                return nil
            }
            let location = mapItem.location
            
            return await getRoute(from: location.coordinate, to: destination, transportType: transportType)
            
        } catch {
            print("❌ DirectionsService: Search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get ETA between multiple places (for itinerary planning)
    /// Get ETA between multiple places (for itinerary planning)
    func getETAsBetweenPlaces(_ places: [Place]) async -> [String] {
        let count = places.count - 1
        guard count > 0 else { return [] }
        
        return await withTaskGroup(of: (Int, String).self) { group in
            for i in 0..<count {
                // Extract raw lat/lng values to avoid main actor isolation
                let place1 = places[i]
                let place2 = places[i+1]
                let lat1 = place1.coordinates_lat
                let lng1 = place1.coordinates_lng
                let lat2 = place2.coordinates_lat
                let lng2 = place2.coordinates_lng
                
                group.addTask {
                    guard let la1 = lat1, let lo1 = lng1,
                          let la2 = lat2, let lo2 = lng2 else {
                        return (i, "N/A")
                    }
                    
                    let c1 = CLLocationCoordinate2D(latitude: la1, longitude: lo1)
                    let c2 = CLLocationCoordinate2D(latitude: la2, longitude: lo2)
                    
                    if let route = await self.getWalkingRoute(from: c1, to: c2) {
                        return (i, route.duration)
                    } else {
                        return (i, "~15 min")
                    }
                }
            }
            
            // Collect results and sort by index
            var results = Array(repeating: "", count: count)
            for await (index, duration) in group {
                if index < results.count {
                    results[index] = duration
                }
            }
            return results
        }
    }
    
    // MARK: - Restaurant Search
    
    /// Search for nearby restaurants using Apple Maps with multiple query fallbacks
    func searchNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 500, query: String? = nil) async -> [RestaurantSuggestion] {
        // If specific query provided (e.g. "Street Food"), use that primarily
        let searchQueries = query != nil ? [query!, "restaurant"] : ["restaurant", "ristorante", "trattoria", "food", "cafe"]
        
        var allResults: [RestaurantSuggestion] = []
        var seenNames: Set<String> = []
        
        for q in searchQueries {
            let results = await performRestaurantSearch(query: q, coordinate: coordinate, radius: radius)
            
            // Add only unique restaurants (by name)
            for restaurant in results {
                if !seenNames.contains(restaurant.name.lowercased()) {
                    seenNames.insert(restaurant.name.lowercased())
                    allResults.append(restaurant)
                }
            }
            
            // If using custom query, we might want to stop if we found good results
            if query != nil && !allResults.isEmpty {
                break
            }
            
            // Stop if we have enough results (generic search)
            if query == nil && allResults.count >= 5 {
                break
            }
        }
        
        // If still empty or too few, try with larger radius
        if allResults.count < 3 {
            print("🍽️ DirectionsService: Few results, trying larger radius (1000m)...")
            let fallbackQuery = query ?? "restaurant"
            let largerRadiusResults = await performRestaurantSearch(query: fallbackQuery, coordinate: coordinate, radius: 1000)
            
            for restaurant in largerRadiusResults {
                if !seenNames.contains(restaurant.name.lowercased()) {
                    seenNames.insert(restaurant.name.lowercased())
                    allResults.append(restaurant)
                }
            }
        }
        
        // Sort by distance and return all (let caller filter and limit)
        allResults.sort { $0.distance < $1.distance }
        
        print("🍽️ DirectionsService: Found \(allResults.count) restaurants near \(coordinate)")
        return allResults
    }
    
    /// Perform a single restaurant search with given query
    private func performRestaurantSearch(query: String, coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [RestaurantSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            var restaurants: [RestaurantSuggestion] = []
            
            for item in response.mapItems.prefix(5) {
                let itemCoord = item.location.coordinate
                let distance = calculateDistance(from: coordinate, to: itemCoord)
                
                // Extract address from map item (iOS 26+)
                let address = item.address?.fullAddress ?? ""
                
                let restaurant = RestaurantSuggestion(
                    id: UUID().uuidString,
                    name: item.name ?? "Restaurant",
                    category: item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "MKPOICategory", with: "") ?? "Restaurant",
                    coordinate: itemCoord,
                    distance: distance,
                    phoneNumber: item.phoneNumber,
                    url: item.url?.absoluteString,
                    address: address
                )
                restaurants.append(restaurant)
            }
            
            return restaurants
            
        } catch {
            print("❌ DirectionsService: Restaurant search error for '\(query)': \(error.localizedDescription)")
            return []
        }
    }
    
    /// Calculate straight-line distance between two coordinates
    func calculateDistance(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let loc2 = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return loc1.distance(from: loc2) // in meters
    }
    
    /// Get walking duration estimate based on distance (avg walking speed 5 km/h)
    func estimateWalkingDuration(distanceMeters: Double) -> String {
        let minutes = Int(distanceMeters / 83.33) // 5 km/h = 83.33 m/min
        if minutes < 1 {
            return "1 min"
        }
        return "\(minutes) min"
    }
}

// MARK: - Restaurant Suggestion Model

struct RestaurantSuggestion: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double // in meters
    let phoneNumber: String?
    let url: String?
    var isAddedToItinerary: Bool = false
    
    // Additional Apple Maps info
    var address: String?
    var priceLevel: Int? // 1-4 ($-$$$$)
    
    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    var priceLevelString: String {
        guard let level = priceLevel else { return "" }
        return String(repeating: "€", count: level)
    }
    
    /// Open restaurant in Apple Maps
    func openInMaps() {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = name
        mapItem.phoneNumber = phoneNumber
        if let urlStr = url, let url = URL(string: urlStr) {
            mapItem.url = url
        }
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    
    /// Call restaurant phone
    func callPhone() {
        guard let phone = phoneNumber?.replacingOccurrences(of: " ", with: ""),
              let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }
    
    /// Open restaurant website
    func openWebsite() {
        guard let urlStr = url, let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url)
    }
    
    // Custom Codable for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, category, distance, phoneNumber, url, isAddedToItinerary
        case latitude, longitude, address, priceLevel
    }
    
    init(id: String, name: String, category: String, coordinate: CLLocationCoordinate2D, distance: Double, phoneNumber: String?, url: String?, address: String? = nil, priceLevel: Int? = nil, isAddedToItinerary: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.distance = distance
        self.phoneNumber = phoneNumber
        self.url = url
        self.address = address
        self.priceLevel = priceLevel
        self.isAddedToItinerary = isAddedToItinerary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        distance = try container.decode(Double.self, forKey: .distance)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        isAddedToItinerary = try container.decodeIfPresent(Bool.self, forKey: .isAddedToItinerary) ?? false
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(distance, forKey: .distance)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(priceLevel, forKey: .priceLevel)
        try container.encode(isAddedToItinerary, forKey: .isAddedToItinerary)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}
