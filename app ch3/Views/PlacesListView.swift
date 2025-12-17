//
//  PlacesListView.swift
//  app ch3
//
//  Modern card list view for places
//

import SwiftUI
import CoreLocation

struct PlacesListView: View {
    @ObservedObject var viewModel: PlacesViewModel
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedPlace: Place?
    @Binding var showingDetail: Bool
    
    // Apply all filters including unvisited, distance, and sorting
    private var placesToDisplay: [Place] {
        viewModel.getFilteredAndSortedPlaces(userLocation: userLocation)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && placesToDisplay.isEmpty {
                    // Loading skeleton
                    ForEach(0..<5, id: \.self) { _ in
                        PlaceCardSkeleton()
                    }
                } else if placesToDisplay.isEmpty {
                    // Empty state
                    EmptyPlacesView(searchText: viewModel.searchText)
                } else {
                    ForEach(placesToDisplay) { place in
                        PlaceCard(
                            place: place,
                            userLocation: userLocation,
                            viewModel: viewModel
                        )
                        .onTapGesture {
                            selectedPlace = place
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(hex: "0f0720"))
    }
}

// Card moderna per ogni luogo
struct PlaceCard: View {
    let place: Place
    let userLocation: CLLocationCoordinate2D?
    let viewModel: PlacesViewModel
    
    private var distance: String? {
        guard let userLocation = userLocation else { return nil }
        
        if let dist = viewModel.distance(from: userLocation, to: place) {
            if dist < 1 {
                return String(format: "%.0f m", dist * 1000)
            } else {
                return String(format: "%.1f km", dist)
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Immagine
            if let imageUrl = place.thumbnail_url ?? place.image_cover,
               let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 180)
                        .overlay {
                            ProgressView()
                        }
                }
            } else {
                // Placeholder con gradiente
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.appAccent.opacity(0.6), Color.appVisited.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 180)
                    .overlay {
                        VStack {
                            Image(systemName: "map.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Luogo Segreto")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
            }
            
            // Contenuto
            VStack(alignment: .leading, spacing: 8) {
                // Titolo
                Text(place.displayName)
                    .font(.headline)
                    .foregroundColor(.appAccent)
                    .lineLimit(2)
                
                // Località
                if let location = place.fullLocation {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.appAccent)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Distanza
                if let distance = distance {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(distance)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Descrizione preview
                if let description = place.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// Skeleton per loading
struct PlaceCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 180)
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 150)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// Empty state
struct EmptyPlacesView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "map" : "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(searchText.isEmpty ? "No places in this area" : "No results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(searchText.isEmpty ? 
                 "Move the map to discover secret places" :
                 "Try a different search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}
