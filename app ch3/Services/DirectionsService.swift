//
//  DirectionsService.swift
//  app ch3
//
//  Service for getting real route/directions data using Apple MapKit (FREE!)
//

import Foundation
import MapKit
import CoreLocation

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
    
    /// Create MKMapItem from coordinate
    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
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
            guard let mapItem = response.mapItems.first,
                  let location = mapItem.placemark.location else {
                print("❌ DirectionsService: Could not find address")
                return nil
            }
            
            return await getRoute(from: location.coordinate, to: destination, transportType: transportType)
            
        } catch {
            print("❌ DirectionsService: Search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get ETA between multiple places (for itinerary planning)
    func getETAsBetweenPlaces(_ places: [Place]) async -> [String] {
        var etas: [String] = []
        
        for i in 0..<(places.count - 1) {
            guard let coord1 = places[i].coordinate,
                  let coord2 = places[i + 1].coordinate else {
                etas.append("N/A")
                continue
            }
            
            if let route = await getWalkingRoute(from: coord1, to: coord2) {
                etas.append(route.duration)
            } else {
                etas.append("~15 min")
            }
        }
        
        return etas
    }
    
    // MARK: - Restaurant Search
    
    /// Search for nearby restaurants using Apple Maps
    func searchNearbyRestaurants(near coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 500) async -> [RestaurantSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
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
                let distance = calculateDistance(from: coordinate, to: item.placemark.coordinate)
                
                let restaurant = RestaurantSuggestion(
                    id: UUID().uuidString,
                    name: item.name ?? "Restaurant",
                    category: item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "MKPOICategory", with: "") ?? "Restaurant",
                    coordinate: item.placemark.coordinate,
                    distance: distance,
                    phoneNumber: item.phoneNumber,
                    url: item.url?.absoluteString
                )
                restaurants.append(restaurant)
            }
            
            // Sort by distance
            restaurants.sort { $0.distance < $1.distance }
            
            print("🍽️ DirectionsService: Found \(restaurants.count) restaurants near \(coordinate)")
            return restaurants
            
        } catch {
            print("❌ DirectionsService: Restaurant search error: \(error.localizedDescription)")
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
    
    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    // Custom Codable for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, category, distance, phoneNumber, url, isAddedToItinerary
        case latitude, longitude
    }
    
    init(id: String, name: String, category: String, coordinate: CLLocationCoordinate2D, distance: Double, phoneNumber: String?, url: String?, isAddedToItinerary: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.distance = distance
        self.phoneNumber = phoneNumber
        self.url = url
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
        try container.encode(isAddedToItinerary, forKey: .isAddedToItinerary)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}
