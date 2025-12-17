//
//  PlaceSwapView.swift
//  app ch3
//
//  View for selecting an alternative place nearby the original one
//

import SwiftUI
import MapKit
import CoreLocation
import Supabase

struct PlaceSwapView: View {
    let originalPlace: Place?
    let originalCoordinate: CLLocationCoordinate2D
    let placesInPlan: Set<Int64>  // IDs of places already in the plan
    let onSelect: (Place) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var nearbyPlaces: [Place] = []
    @State private var isLoading = true
    @State private var searchRadius: Double = 5.0 // km
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with original place
                if let original = originalPlace {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replacing")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(original.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                }
                
                // Radius slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Search radius")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(Int(searchRadius)) km")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color(hex: "a855f7"))
                    }
                    
                    Slider(value: $searchRadius, in: 1...20, step: 1)
                        .tint(Color(hex: "a855f7"))
                        .onChange(of: searchRadius) { _, _ in
                            Task { await fetchNearbyPlaces() }
                        }
                }
                .padding()
                
                // Results
                if isLoading {
                    Spacer()
                    ProgressView("Searching nearby places...")
                        .foregroundColor(.white)
                    Spacer()
                } else if nearbyPlaces.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.5))
                        Text("No alternatives found")
                            .foregroundColor(.white.opacity(0.7))
                        Text("Try increasing the search radius")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(nearbyPlaces) { place in
                                PlaceSwapCard(place: place) {
                                    onSelect(place)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(hex: "0f0720"))
            .navigationTitle("Choose Alternative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .task {
            await fetchNearbyPlaces()
        }
    }
    
    private func fetchNearbyPlaces() async {
        isLoading = true
        
        do {
            let client = SupabaseManager.shared.client
            
            // Calculate bounding box
            let radiusInDegrees = searchRadius / 111.0
            let minLat = originalCoordinate.latitude - radiusInDegrees
            let maxLat = originalCoordinate.latitude + radiusInDegrees
            let minLng = originalCoordinate.longitude - radiusInDegrees
            let maxLng = originalCoordinate.longitude + radiusInDegrees
            
            let response: [Place] = try await client
                .from("places")
                .select()
                .gte("coordinates_lat", value: minLat)
                .lte("coordinates_lat", value: maxLat)
                .gte("coordinates_lng", value: minLng)
                .lte("coordinates_lng", value: maxLng)
                .execute()
                .value
            
            // Filter out places already in plan and sort by distance
            let filtered = response.filter { place in
                !placesInPlan.contains(place.id)
            }
            
            // Sort by distance from original
            let sorted = filtered.sorted { p1, p2 in
                let d1 = distanceFrom(originalCoordinate, to: p1)
                let d2 = distanceFrom(originalCoordinate, to: p2)
                return d1 < d2
            }
            
            nearbyPlaces = Array(sorted.prefix(20))
            print("🔄 Found \(nearbyPlaces.count) alternatives nearby")
            
        } catch {
            print("❌ Error fetching nearby places: \(error)")
            nearbyPlaces = []
        }
        
        isLoading = false
    }
    
    private func distanceFrom(_ coord: CLLocationCoordinate2D, to place: Place) -> Double {
        guard let placeCoord = place.coordinate else { return Double.infinity }
        let from = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let to = CLLocation(latitude: placeCoord.latitude, longitude: placeCoord.longitude)
        return from.distance(from: to)
    }
}

// MARK: - Place Swap Card

struct PlaceSwapCard: View {
    let place: Place
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Thumbnail
                if let imageUrl = place.thumbnail_url ?? place.image_cover,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "mappin")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let category = place.categoryName {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(Color(hex: "a855f7"))
                    }
                    
                    if let desc = place.cleanDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(12)
        }
    }
}
