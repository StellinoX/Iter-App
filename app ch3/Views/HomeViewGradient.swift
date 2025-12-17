//
//  HomeViewGradient.swift
//  app ch3
//
//  EXPERIMENTAL: Home page with animated purple gradient background
//  Copy of HomeView for testing gradient effects
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

// MARK: - Animated Purple Gradient Background with Moving Light

struct AnimatedGradientBackground: View {
    @State private var lightPosition = CGPoint(x: 0.3, y: 0.3)
    
    // Timer to move light randomly
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Base purple gradient (static)
            LinearGradient(
                colors: [
                    Color(hex: "1a0533"),  // Very dark purple
                    Color(hex: "2d1b4e"),  // Dark purple
                    Color(hex: "1a0533")   // Very dark purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Moving light spot
            Canvas { context, size in
                let center = CGPoint(
                    x: size.width * lightPosition.x,
                    y: size.height * lightPosition.y
                )
                
                // Create radial gradient for the light
                let gradient = Gradient(colors: [
                    Color(hex: "a855f7").opacity(0.6),  // Purple light center
                    Color(hex: "7c3aed").opacity(0.3),  // Violet
                    Color(hex: "4c1d95").opacity(0.1),  // Dark purple
                    Color.clear
                ])
                
                let shading = GraphicsContext.Shading.radialGradient(
                    gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: size.width * 0.6
                )
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - size.width * 0.6,
                        y: center.y - size.width * 0.6,
                        width: size.width * 1.2,
                        height: size.width * 1.2
                    )),
                    with: shading
                )
            }
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            moveLight()
        }
        .onAppear {
            moveLight()
        }
    }
    
    private func moveLight() {
        withAnimation(.easeInOut(duration: 3.0)) {
            // Random position within bounds
            lightPosition = CGPoint(
                x: CGFloat.random(in: 0.2...0.8),
                y: CGFloat.random(in: 0.2...0.8)
            )
        }
    }
}

// Alternative: Multiple floating light orbs
struct FloatingLightsBackground: View {
    @State private var light1 = CGPoint(x: 0.3, y: 0.2)
    @State private var light2 = CGPoint(x: 0.7, y: 0.6)
    @State private var light3 = CGPoint(x: 0.5, y: 0.8)
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Base dark purple
            Color(hex: "0f0720")
            
            // Light orb 1 - Pink/Purple
            lightOrb(position: light1, color: Color(hex: "f472b6"), size: 0.5)
            
            // Light orb 2 - Purple
            lightOrb(position: light2, color: Color(hex: "a855f7"), size: 0.4)
            
            // Light orb 3 - Blue-Purple
            lightOrb(position: light3, color: Color(hex: "818cf8"), size: 0.35)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            moveLights()
        }
        .onAppear {
            moveLights()
        }
    }
    
    private func lightOrb(position: CGPoint, color: Color, size: CGFloat) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.5),
                            color.opacity(0.2),
                            color.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * size
                    )
                )
                .frame(width: geo.size.width * size * 2, height: geo.size.width * size * 2)
                .position(
                    x: geo.size.width * position.x,
                    y: geo.size.height * position.y
                )
                .blur(radius: 30)
        }
    }
    
    private func moveLights() {
        withAnimation(.easeInOut(duration: 2.5)) {
            light1 = CGPoint(x: .random(in: 0.1...0.5), y: .random(in: 0.1...0.4))
        }
        withAnimation(.easeInOut(duration: 3.0)) {
            light2 = CGPoint(x: .random(in: 0.5...0.9), y: .random(in: 0.3...0.7))
        }
        withAnimation(.easeInOut(duration: 3.5)) {
            light3 = CGPoint(x: .random(in: 0.2...0.8), y: .random(in: 0.6...0.9))
        }
    }
}

// MARK: - HomeView with Gradient

struct HomeViewGradient: View {
    @ObservedObject var viewModel: PlacesViewModel
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedPlace: Place?
    @Binding var showingDetail: Bool
    let onPlanTrip: () -> Void
    
    // Use floating lights background
    @State private var useMeshGradient = true
    
    // Cache trending places to avoid re-shuffle on each render
    @State private var cachedTrendingPlaces: [Place] = []
    
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
        if !cachedTrendingPlaces.isEmpty {
            return cachedTrendingPlaces
        }
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
        viewModel.validPlaces
            .filter { !viewModel.isVisited($0.id) && !viewModel.isFavorite($0.id) }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background with moving lights
            if useMeshGradient {
                FloatingLightsBackground()  // Multiple floating orbs
            } else {
                AnimatedGradientBackground()  // Single moving spotlight
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Loading state
                    if viewModel.isLoading && viewModel.places.isEmpty {
                        loadingState
                    }
                    
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
                    
                    // Empty state
                    if !viewModel.isLoading && viewModel.places.isEmpty && hasLoadedInitially {
                        emptyState
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
        }
        .task {
            await loadPlacesForHome()
        }
        .onAppear {
            if !hasLoadedInitially && viewModel.places.isEmpty {
                Task {
                    await loadPlacesForHome()
                }
            }
        }
    }
    
    @State private var hasLoadedInitially = false
    
    private func loadPlacesForHome() async {
        guard !hasLoadedInitially || viewModel.places.isEmpty else { return }
        
        let region: MKCoordinateRegion
        if let userLoc = userLocation {
            region = MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        } else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.9, longitude: 12.5),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        }
        
        await viewModel.fetchPlacesInRegion(region)
        hasLoadedInitially = true
        
        if cachedTrendingPlaces.isEmpty && !viewModel.validPlaces.isEmpty {
            cachedTrendingPlaces = computeTrendingPlaces()
        }
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
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Discovering hidden gems...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))
            
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func placesSection(title: String, icon: String, places: [Place]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button {
                    // Show all
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(places) { place in
                        GradientPlaceCard(place: place, userLocation: userLocation) {
                            selectedPlace = place
                            showingDetail = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Gradient Place Card (with glassmorphism)

struct GradientPlaceCard: View {
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
                // Image
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
                
                // Text content
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
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .lineLimit(1)
                }
                .frame(height: 50, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(width: 160, height: 158)
            .background(.ultraThinMaterial)
            .glassEffect()
            .cornerRadius(16)
        }
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.5))
            }
    }
}

#Preview {
    NavigationStack {
        HomeViewGradient(
            viewModel: PlacesViewModel(),
            userLocation: nil,
            selectedPlace: .constant(nil),
            showingDetail: .constant(false),
            onPlanTrip: {}
        )
    }
}
