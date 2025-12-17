//
//  FavoritesView.swift
//  app ch3
//
//  Favorite places list view
//

import SwiftUI
import CoreLocation

struct FavoritesView: View {
    @ObservedObject var viewModel: PlacesViewModel
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedPlace: Place?
    @Binding var showingDetail: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.favoritePlacesFull.isEmpty {
                    // Empty state
                    EmptyFavoritesView()
                } else {
                    ForEach(viewModel.favoritePlacesFull) { place in
                        PlaceCard(
                            place: place,
                            userLocation: userLocation,
                            viewModel: viewModel
                        )
                        .onTapGesture {
                            selectedPlace = place
                            showingDetail = true
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(hex: "0f0720"))
        .task {
            await viewModel.fetchFavoritePlaces()
        }
    }
}

// Empty state per preferiti
struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No favorites")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.appAccent)
            
            Text("Add places to favorites by tapping the heart in details")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}
