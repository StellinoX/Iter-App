//
//  DayRouteMapView.swift
//  app ch3
//
//  Shows an in-app map with the day's itinerary route
//

import SwiftUI
import MapKit

struct DayRouteMapView: View {
    let dayNumber: Int
    let cityName: String
    let activities: [TripActivity]
    @Environment(\.dismiss) var dismiss
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = true
    @State private var waypoints: [RouteWaypoint] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                mapContent
                
                if isLoadingRoutes {
                    loadingOverlay
                }
            }
            .navigationTitle("Day \(dayNumber) - \(cityName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.appAccent)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openInAppleMaps()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open in Maps")
                        }
                        .font(.subheadline)
                        .foregroundColor(.appAccent)
                    }
                }
            }
        }
        .task {
            await loadWaypointsAndRoutes()
        }
    }
    
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Waypoint markers
            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                Annotation(waypoint.name, coordinate: waypoint.coordinate) {
                    waypointMarker(index: index + 1, name: waypoint.name)
                }
            }
            
            // Route polylines
            ForEach(routes, id: \.self) { route in
                MapPolyline(route.polyline)
                    .stroke(Color.appAccent, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
    
    private func waypointMarker(index: Int, name: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                
                Text("\(index)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .lineLimit(1)
        }
    }
    
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.appAccent)
            Text("Calculating route...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(24)
        .background(Color.appBackground.opacity(0.95))
        .cornerRadius(16)
    }
    
    private func loadWaypointsAndRoutes() async {
        // First, get all waypoints (either from saved coordinates or geocode)
        var loadedWaypoints: [RouteWaypoint] = []
        
        for activity in activities {
            if let lat = activity.coordinatesLat, let lng = activity.coordinatesLng {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                loadedWaypoints.append(RouteWaypoint(name: activity.placeName, coordinate: coord))
            } else {
                // Geocode by name
                if let coord = await geocodePlace(name: activity.placeName, city: cityName) {
                    loadedWaypoints.append(RouteWaypoint(name: activity.placeName, coordinate: coord))
                }
            }
        }
        
        await MainActor.run {
            waypoints = loadedWaypoints
        }
        
        // Calculate routes between consecutive waypoints
        guard loadedWaypoints.count >= 2 else {
            await MainActor.run { isLoadingRoutes = false }
            return
        }
        
        var calculatedRoutes: [MKRoute] = []
        
        for i in 0..<(loadedWaypoints.count - 1) {
            let source = loadedWaypoints[i]
            let destination = loadedWaypoints[i + 1]
            
            if let route = await calculateRoute(from: source.coordinate, to: destination.coordinate) {
                calculatedRoutes.append(route)
            }
        }
        
        await MainActor.run {
            routes = calculatedRoutes
            isLoadingRoutes = false
            
            // Set camera to fit all waypoints
            if !waypoints.isEmpty {
                let coordinates = waypoints.map { $0.coordinate }
                let region = regionToFit(coordinates: coordinates)
                cameraPosition = .region(region)
            }
        }
    }
    
    private func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> MKRoute? {
        let request = MKDirections.Request()
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        request.source = MKMapItem(location: sourceLocation, address: nil)
        request.destination = MKMapItem(location: destLocation, address: nil)
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return response.routes.first
        } catch {
            print("❌ Route calculation failed: \(error)")
            return nil
        }
    }
    
    private func geocodePlace(name: String, city: String) async -> CLLocationCoordinate2D? {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(name), \(city)"
        
        let search = MKLocalSearch(request: searchRequest)
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }
    
    private func regionToFit(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLng = coordinates[0].longitude
        var maxLng = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,
            longitudeDelta: (maxLng - minLng) * 1.5 + 0.01
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func openInAppleMaps() {
        guard waypoints.count >= 2 else { return }
        
        let startCoord = waypoints.first!.coordinate
        let endCoord = waypoints.last!.coordinate
        
        var urlString = "maps://?saddr=\(startCoord.latitude),\(startCoord.longitude)"
        urlString += "&daddr=\(endCoord.latitude),\(endCoord.longitude)"
        
        // Add intermediate waypoints
        for i in 1..<(waypoints.count - 1) {
            let waypointCoord = waypoints[i].coordinate
            urlString += "+to:\(waypointCoord.latitude),\(waypointCoord.longitude)"
        }
        
        urlString += "&dirflg=w"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Route Waypoint Model

struct RouteWaypoint: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    DayRouteMapView(
        dayNumber: 1,
        cityName: "Roma",
        activities: []
    )
}
