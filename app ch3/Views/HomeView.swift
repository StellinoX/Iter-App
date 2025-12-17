//
//  HomeView.swift
//  app ch3
//
//  New home page with trip planning CTA and place suggestions
//

import SwiftUI
import CoreLocation
import MapKit

struct HomeView: View {
    @ObservedObject var viewModel: PlacesViewModel
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedPlace: Place?
    @Binding var showingDetail: Bool
    let onPlanTrip: () -> Void
    
    // Cache trending places to avoid re-shuffle on each render
    @State private var cachedTrendingPlaces: [Place] = []
    @State private var showingAllFavorites = false
    
    // Favorite places from viewModel
    private var favoritePlaces: [Place] {
        viewModel.validPlaces.filter { viewModel.isFavorite($0.id) }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Good Morning"
        case 12..<18: return "Good Afternoon"
        case 18..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private var nearbyPlaces: [Place] {
        guard let userLoc = userLocation else { return [] }
        return viewModel.validPlaces
            .filter { $0.coordinate != nil }
            .sorted { place1, place2 in
                let loc1 = CLLocation(latitude: place1.coordinate!.latitude, longitude: place1.coordinate!.longitude)
                let loc2 = CLLocation(latitude: place2.coordinate!.latitude, longitude: place2.coordinate!.longitude)
                let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                return loc1.distance(from: userCL) < loc2.distance(from: userCL)
            }
            .prefix(10)
            .map { $0 }
    }
    
    private var trendingPlaces: [Place] {
        // Return cached if available, else compute once
        if !cachedTrendingPlaces.isEmpty {
            return cachedTrendingPlaces
        }
        // Use deterministic selection based on day (changes daily, not on every render)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let sorted = viewModel.validPlaces.sorted { $0.id < $1.id }
        let offset = dayOfYear % max(1, sorted.count)
        var result: [Place] = []
        for i in 0..<min(8, sorted.count) {
            let index = (offset + i * 3) % sorted.count
            if !result.contains(where: { $0.id == sorted[index].id }) {
                result.append(sorted[index])
            }
        }
        return result
    }
    
    private var suggestedPlaces: [Place] {
        // Suggest unvisited places
        viewModel.validPlaces
            .filter { !viewModel.isVisited($0.id) && !viewModel.isFavorite($0.id) }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                

                
                // Favorites Section (FIRST - with Show All)
                if !favoritePlaces.isEmpty {
                    favoritesSection
                }
                
                // Show skeleton sections during loading
                if viewModel.isLoading && viewModel.places.isEmpty {
                    skeletonSection(title: "Trending", icon: "flame.fill")
                    skeletonSection(title: "Nearby", icon: "location.fill")
                    skeletonSection(title: "Suggested", icon: "sparkles")
                } else {
                    // Trending Places
                    if !trendingPlaces.isEmpty {
                        placesSection(title: "Trending", icon: "flame.fill", places: trendingPlaces)
                    }
                    
                    // Nearby Places
                    if !nearbyPlaces.isEmpty {
                        placesSection(title: "Nearby", icon: "location.fill", places: nearbyPlaces)
                    }
                    
                    // Suggested for You
                    if !suggestedPlaces.isEmpty {
                        placesSection(title: "Suggested for You", icon: "sparkles", places: suggestedPlaces)
                    }
                }
                
                // Empty state (no places after loading)
                if !viewModel.isLoading && viewModel.places.isEmpty && hasLoadedInitially {
                    emptyState
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .background(Color(hex: "0f0720"))
        .task(id: "initial-load") {
            // Primary load - runs immediately
            await loadPlacesForHome()
        }
        .onAppear {
            // Backup: trigger load if task didn't run or failed
            Task {
                // Small delay to let .task run first
                try? await Task.sleep(nanoseconds: 500_000_000)
                if viewModel.places.isEmpty && !viewModel.isLoading {
                    print("🔄 HomeView: Backup load triggered")
                    await loadPlacesForHome()
                }
            }
        }
    }
    
    @State private var hasLoadedInitially = false
    @State private var isLoadingHome = false
    
    private func loadPlacesForHome() async {
        // Prevent concurrent loads
        guard !isLoadingHome else { return }
        isLoadingHome = true
        
        defer { isLoadingHome = false }
        
        // Skip if we already have data
        if hasLoadedInitially && !viewModel.places.isEmpty {
            return
        }
        
        print("🏠 HomeView: Loading places...")
        
        let region: MKCoordinateRegion
        if let userLoc = userLocation {
            // Larger region around user for more places
            region = MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        } else {
            // Default to Italy with wide span
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.9, longitude: 12.5),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        }
        
        // Fetch places and favorites in parallel
        async let placesTask: () = viewModel.fetchPlacesInRegion(region)
        async let favoritesTask: () = viewModel.fetchFavoritePlaces()
        
        _ = await (placesTask, favoritesTask)
        
        hasLoadedInitially = true
        
        // Cache trending places once loaded
        if cachedTrendingPlaces.isEmpty && !viewModel.validPlaces.isEmpty {
            cachedTrendingPlaces = computeTrendingPlaces()
        }
        
        print("🏠 HomeView: Loaded \(viewModel.places.count) places, \(viewModel.favoritePlacesFull.count) favorites")
    }
    
    private func computeTrendingPlaces() -> [Place] {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let sorted = viewModel.validPlaces.sorted { $0.id < $1.id }
        guard !sorted.isEmpty else { return [] }
        let offset = dayOfYear % sorted.count
        var result: [Place] = []
        for i in 0..<min(8, sorted.count) {
            let index = (offset + i * 3) % sorted.count
            if !result.contains(where: { $0.id == sorted[index].id }) {
                result.append(sorted[index])
            }
        }
        return result
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greeting)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                
                Text("Where will you explore today?")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 20)
    }
    
    private var planTripCTA: some View {
        Button(action: onPlanTrip) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Your Adventure")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.black)
                    
                    Text("Get AI-powered itineraries")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "airplane.departure")
                    .font(.system(size: 40))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "BFFF00"), Color(hex: "9FE000")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
    }
    

    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No places found nearby")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try moving to a different area on the map")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Button {
                hasLoadedInitially = false
                Task {
                    await loadPlacesForHome()
                }
            } label: {
                Text("Retry")
                    .foregroundColor(.appAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appAccent.opacity(0.2))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    // MARK: - Favorites Section (with Show All)
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.white)
                Text("Favorites")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button {
                    showingAllFavorites = true
                } label: {
                    Text("Show all")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(favoritePlaces.prefix(10)) { place in
                        HomePlaceCard(place: place, userLocation: userLocation) {
                            selectedPlace = place
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAllFavorites) {
            AllFavoritesModal(
                places: favoritePlaces,
                userLocation: userLocation,
                onSelect: { place in
                    selectedPlace = place
                    showingAllFavorites = false
                }
            )
        }
    }
    
    // MARK: - Places Section (no See All button)
    private func placesSection(title: String, icon: String, places: [Place]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(places) { place in
                        HomePlaceCard(place: place, userLocation: userLocation) {
                            selectedPlace = place
                        }
                    }
                }
            }
        }
    }
    
    // Skeleton section for loading state
    private func skeletonSection(title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.5))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard()
                    }
                }
            }
        }
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder with shimmer
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.5),
                            Color.gray.opacity(0.3)
                        ],
                        startPoint: isAnimating ? .leading : .trailing,
                        endPoint: isAnimating ? .trailing : .leading
                    )
                )
                .frame(width: 160, height: 100)
            
            // Text placeholders
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 160, height: 158)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - All Favorites Modal
struct AllFavoritesModal: View {
    let places: [Place]
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (Place) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(places) { place in
                        Button {
                            onSelect(place)
                        } label: {
                            HStack(spacing: 12) {
                                // Thumbnail
                                if let imageUrl = place.image_cover ?? place.thumbnail_url,
                                   let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.white.opacity(0.1)
                                    }
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(10)
                                    .clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let city = place.city {
                                        Text(city)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color(hex: "0f0720"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Home Place Card

struct HomePlaceCard: View {
    let place: Place
    let userLocation: CLLocationCoordinate2D?
    let onTap: () -> Void
    
    private var distanceString: String? {
        guard let userLoc = userLocation,
              let placeLoc = place.coordinate else { return nil }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let placeCL = CLLocation(latitude: placeLoc.latitude, longitude: placeLoc.longitude)
        let distance = userCL.distance(from: placeCL) / 1000
        if distance < 1 {
            return String(format: "%.0f m", distance * 1000)
        }
        return String(format: "%.1f km", distance)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image - fixed size
                ZStack {
                    if let imageUrl = place.image_cover ?? place.thumbnail_url,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .failure:
                                placeholderImage
                            @unknown default:
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 160, height: 100)
                .clipped()
                
                // Text content - fixed height
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let city = place.city {
                            Text(city)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        
                        if let distance = distanceString {
                            Text("• \(distance)")
                                .font(.caption)
                                .foregroundColor(Color.appAccent)
                        }
                    }
                    .lineLimit(1)
                }
                .frame(height: 50, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(width: 160, height: 158) // Fixed total height
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(16)
        }
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.7))
            }
    }
}

#Preview {
    HomeView(
        viewModel: PlacesViewModel(),
        userLocation: nil,
        selectedPlace: .constant(nil),
        showingDetail: .constant(false),
        onPlanTrip: {}
    )
}

