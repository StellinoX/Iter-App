//
//  TripPlannerView.swift
//  app ch3
//
//  Trip planning flow: select city, dates, places, generate AI itinerary
//

import SwiftUI
import MapKit
import Supabase

struct TripPlannerView: View {
    @Binding var isPresented: Bool
    @State private var step: PlannerStep = .city
    @State private var selectedCity: String = ""
    @State private var selectedRegion: MKCoordinateRegion?
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3 * 24 * 60 * 60) // 3 days default
    @State private var hotelAddress: String = ""
    @State private var isGenerating = false
    @State private var generatedTrip: Trip?
    
    // AI Suggestions
    @State private var allPlaces: [Place] = []
    @State private var suggestedPlaces: [Place] = []
    @State private var selectedPlaces: [Place] = []
    @State private var isLoadingSuggestions = false
    
    // Tag/Category filter
    @State private var availableTags: [String] = []
    @State private var selectedTags: Set<String> = []
    @State private var isLoadingTags = false
    
    @StateObject private var geminiService = GeminiService()
    private let directionsService = DirectionsService()
    
    private var requiredPlaces: Int {
        calculateDays() * 4 // 4 places per day
    }
    
    enum PlannerStep {
        case city, dates, tagFilter, aiSelection, generating, result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                switch step {
                case .city:
                    citySelectionView
                case .dates:
                    dateSelectionView
                case .tagFilter:
                    tagFilterView
                case .aiSelection:
                    aiSelectionView
                case .generating:
                    generatingView
                case .result:
                    if let trip = generatedTrip {
                        TripDetailView(trip: trip, isPresented: $isPresented)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step != .city {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.appAccent)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch step {
        case .city: return "Choose Destination"
        case .dates: return "Select Dates"
        case .tagFilter: return "What to Visit"
        case .aiSelection: return "AI Suggestions"
        case .generating: return "Creating Itinerary"
        case .result: return "Your Trip"
        }
    }
    
    // MARK: - City Selection
    
    private var citySelectionView: some View {
        CitySearchView(isPresented: .constant(true)) { region, cityName in
            selectedCity = cityName
            selectedRegion = region
            withAnimation {
                step = .dates
            }
        }
    }
    
    // MARK: - Date Selection
    
    private var dateSelectionView: some View {
        VStack(spacing: 24) {
            // City selected
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.appAccent)
                
                VStack(alignment: .leading) {
                    Text("Destination")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(selectedCity)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button {
                    step = .city
                } label: {
                    Text("Change")
                        .font(.caption)
                        .foregroundColor(.appAccent)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(12)
            
            // Date pickers
            VStack(spacing: 16) {
                Text("When do you go?")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.appAccent)
                        .foregroundColor(.white)
                    
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.appAccent)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                
                // Duration indicator
                let days = calculateDays()
                Text("\(days) \(days == 1 ? "day" : "days") trip")
                    .font(.headline)
                    .foregroundColor(Color.appAccent)
            }
            
            // Hotel input
            VStack(alignment: .leading, spacing: 8) {
                Text("Where are you staying?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Hotel/Airbnb address (optional)", text: $hotelAddress)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Next button - go to places selection
            Button {
                goToTagFilter()
            } label: {
                HStack {
                    Image(systemName: "arrow.right")
                    Text("Choose Places")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "BFFF00"))
                .cornerRadius(16)
            }
        }
        .padding()
    }
    
    // MARK: - Tag Filter View
    
    private var tagFilterView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("What do you want to see?")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Select the types of places you're interested in")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if isLoadingTags {
                Spacer()
                ProgressView("Loading categories...")
                    .foregroundColor(.white)
                Spacer()
            } else {
                // Tag chips in a flow layout
                ScrollView {
                    FlowLayout(spacing: 10) {
                        ForEach(availableTags, id: \.self) { tag in
                            TagChip(
                                tag: tag,
                                isSelected: selectedTags.contains(tag),
                                onTap: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Select all / Clear buttons
                HStack {
                    Button("Select All") {
                        selectedTags = Set(availableTags)
                    }
                    .font(.caption)
                    .foregroundColor(.appAccent)
                    
                    Spacer()
                    
                    Button("Clear") {
                        selectedTags.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            
            // Continue button
            Button {
                goToAISelection()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Continue with \(selectedTags.count) categories")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTags.isEmpty ? Color.gray : Color.appAccent)
                .cornerRadius(16)
            }
            .disabled(selectedTags.isEmpty)
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    // MARK: - AI Selection View
    
    private var aiSelectionView: some View {
        VStack(spacing: 16) {
            // Progress header
            VStack(spacing: 8) {
                HStack {
                    Text("\(selectedPlaces.count)/\(requiredPlaces) places")
                        .font(.headline)
                        .foregroundColor(.appAccent)
                    Spacer()
                    Text("\(calculateDays()) days trip")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width * CGFloat(selectedPlaces.count) / CGFloat(max(requiredPlaces, 1)), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal)
            
            if isLoadingSuggestions {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.appAccent)
                    Text("AI is finding the best places...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                // Suggestion cards
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Select places you'd like to visit")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ForEach(suggestedPlaces, id: \.id) { place in
                            PlaceSuggestionCard(
                                place: place,
                                isSelected: selectedPlaces.contains(where: { $0.id == place.id }),
                                onToggle: {
                                    togglePlaceSelection(place)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Get more suggestions button
                Button {
                    Task { await loadNextSuggestions() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("More")
                    }
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent.opacity(0.2))
                    .cornerRadius(12)
                }
                
                // Complete/Next button
                Button {
                    if selectedPlaces.count >= requiredPlaces {
                        generateItinerary()
                    } else {
                        Task { await loadNextSuggestions() }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedPlaces.count >= requiredPlaces ? "sparkles" : "arrow.right")
                        Text(selectedPlaces.count >= requiredPlaces ? "Generate" : "Next (\(selectedPlaces.count)/\(requiredPlaces))")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private func togglePlaceSelection(_ place: Place) {
        if let index = selectedPlaces.firstIndex(where: { $0.id == place.id }) {
            selectedPlaces.remove(at: index)
        } else {
            selectedPlaces.append(place)
        }
    }
    
    // MARK: - Generating View
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.appAccent)
            
            Text("Creating your perfect itinerary...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Using AI to find the best places and routes")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func calculateDays() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    private func goBack() {
        withAnimation {
            switch step {
            case .dates: step = .city
            case .tagFilter: step = .dates
            case .aiSelection: step = .tagFilter
            case .result: step = .aiSelection
            default: break
            }
        }
    }
    
    private func goToTagFilter() {
        isLoadingTags = true
        withAnimation {
            step = .tagFilter
        }
        
        Task {
            // Fetch all places for the city
            allPlaces = await fetchPlacesForCity()
            
            // Extract unique tags from places
            var tags = Set<String>()
            for place in allPlaces {
                if let category = place.categoryName {
                    tags.insert(category)
                }
            }
            availableTags = Array(tags).sorted()
            
            // Pre-select all tags
            selectedTags = tags
            
            isLoadingTags = false
        }
    }
    
    private func goToAISelection() {
        isLoadingSuggestions = true
        withAnimation {
            step = .aiSelection
        }
        
        Task {
            // Filter places by selected tags
            let filteredPlaces = allPlaces.filter { place in
                guard let category = place.categoryName else { return false }
                return selectedTags.contains(category)
            }
            allPlaces = filteredPlaces
            
            await loadNextSuggestions()
        }
    }
    
    private func loadNextSuggestions() async {
        isLoadingSuggestions = true
        
        // Filter out already selected places
        let availablePlaces = allPlaces.filter { place in
            !selectedPlaces.contains(where: { $0.id == place.id })
        }
        
        // Get AI suggestions
        let suggestedIds = await geminiService.suggestNextPlaces(
            availablePlaces: availablePlaces,
            selectedPlaces: selectedPlaces,
            hotelAddress: hotelAddress,
            count: 4
        )
        
        // Map IDs to places
        if !suggestedIds.isEmpty {
            suggestedPlaces = suggestedIds.compactMap { id in
                availablePlaces.first(where: { $0.id == id })
            }
        } else {
            // Fallback: show first 4 available places
            suggestedPlaces = Array(availablePlaces.prefix(4))
        }
        
        isLoadingSuggestions = false
    }
    
    private func generateItinerary() {
        withAnimation {
            step = .generating
        }
        
        Task {
            // Create trip structure
            var trip = Trip(cityName: selectedCity, startDate: startDate, endDate: endDate)
            
            // Generate with AI using selected places and hotel
            if let aiDays = await geminiService.generateItinerary(
                city: selectedCity,
                days: calculateDays(),
                places: selectedPlaces,
                hotelAddress: hotelAddress
            ) {
                var updatedDays = aiDays
                
                for (dayIndex, day) in aiDays.enumerated() {
                    // Track coordinates for this day's activities (index, coordinate, time)
                    var dayCoordinates: [(index: Int, coord: CLLocationCoordinate2D, time: String)] = []
                    
                    for (activityIndex, activity) in day.activities.enumerated() {
                        // Find the place by name to get coordinates
                        if let place = selectedPlaces.first(where: { $0.displayName == activity.placeName }),
                           let coord = place.coordinate {
                            dayCoordinates.append((index: activityIndex, coord: coord, time: activity.startTime))
                            
                            // Calculate distance from previous activity
                            if activityIndex > 0,
                               let prevPlace = selectedPlaces.first(where: { $0.displayName == day.activities[activityIndex - 1].placeName }),
                               let prevCoord = prevPlace.coordinate {
                                
                                // Try to get real route, fallback to estimation
                                if let route = await directionsService.getWalkingRoute(from: prevCoord, to: coord) {
                                    updatedDays[dayIndex].activities[activityIndex].transportDuration = route.duration
                                    updatedDays[dayIndex].activities[activityIndex].transportDetails = "📍 \(route.distance)"
                                } else {
                                    // Fallback: use straight-line distance estimation
                                    let distance = directionsService.calculateDistance(from: prevCoord, to: coord)
                                    let duration = directionsService.estimateWalkingDuration(distanceMeters: distance)
                                    updatedDays[dayIndex].activities[activityIndex].transportDuration = duration
                                    updatedDays[dayIndex].activities[activityIndex].transportDetails = "📍 ~\(Int(distance))m"
                                }
                            }
                        }
                    }
                    
                    // Find lunch slot (activity before/around 12:00-13:00)
                    var lunchActivityIndex: Int?
                    var lunchCoord: CLLocationCoordinate2D?
                    for item in dayCoordinates {
                        if let hour = parseHour(from: item.time), hour >= 11 && hour <= 13 {
                            lunchActivityIndex = item.index
                            lunchCoord = item.coord
                            break
                        }
                    }
                    
                    // Find dinner slot (activity before/around 19:00-21:00)
                    var dinnerActivityIndex: Int?
                    var dinnerCoord: CLLocationCoordinate2D?
                    for item in dayCoordinates.reversed() {
                        if let hour = parseHour(from: item.time), hour >= 18 && hour <= 21 {
                            dinnerActivityIndex = item.index
                            dinnerCoord = item.coord
                            break
                        }
                    }
                    
                    // Search for lunch restaurants
                    if let idx = lunchActivityIndex, let coord = lunchCoord {
                        let restaurants = await directionsService.searchNearbyRestaurants(near: coord, radius: 400)
                        if !restaurants.isEmpty {
                            updatedDays[dayIndex].lunchSuggestions = MealSuggestion(
                                afterActivityIndex: idx,
                                restaurants: Array(restaurants.prefix(3)),
                                mealType: .lunch
                            )
                        }
                    }
                    
                    // Search for dinner restaurants
                    if let idx = dinnerActivityIndex, let coord = dinnerCoord {
                        let restaurants = await directionsService.searchNearbyRestaurants(near: coord, radius: 400)
                        if !restaurants.isEmpty {
                            updatedDays[dayIndex].dinnerSuggestions = MealSuggestion(
                                afterActivityIndex: idx,
                                restaurants: Array(restaurants.prefix(3)),
                                mealType: .dinner
                            )
                        }
                    }
                }
                
                trip.days = updatedDays
            }
            
            generatedTrip = trip
            
            withAnimation {
                step = .result
            }
        }
    }
    
    private func fetchPlacesForCity() async -> [Place] {
        print("🗺️ Fetching places for city: \(selectedCity)")
        
        do {
            let client = SupabaseManager.shared.client
            
            // First try to search by city name
            var response: [Place] = try await client
                .from("places")
                .select()
                .ilike("city", pattern: "%\(selectedCity)%")
                .limit(30)
                .execute()
                .value
            
            print("🗺️ Found \(response.count) places by city name")
            
            // If no results by city name, try by region coordinates
            if response.isEmpty, let region = selectedRegion {
                print("🗺️ Trying coordinate-based search...")
                let latMin = region.center.latitude - region.span.latitudeDelta
                let latMax = region.center.latitude + region.span.latitudeDelta
                let lngMin = region.center.longitude - region.span.longitudeDelta
                let lngMax = region.center.longitude + region.span.longitudeDelta
                
                response = try await client
                    .from("places")
                    .select()
                    .gte("coordinates_lat", value: latMin)
                    .lte("coordinates_lat", value: latMax)
                    .gte("coordinates_lng", value: lngMin)
                    .lte("coordinates_lng", value: lngMax)
                    .limit(30)
                    .execute()
                    .value
                
                print("🗺️ Found \(response.count) places by coordinates")
            }
            
            // If still no results, get any places from country
            if response.isEmpty {
                print("🗺️ Trying country-based search...")
                response = try await client
                    .from("places")
                    .select()
                    .limit(30)
                    .execute()
                    .value
                
                print("🗺️ Found \(response.count) random places as fallback")
            }
            
            return response
        } catch {
            print("❌ Error fetching places for city: \(error)")
            return []
        }
    }
    
    /// Parse hour from time string like "09:00" or "14:30"
    private func parseHour(from timeString: String) -> Int? {
        let components = timeString.split(separator: ":")
        guard let hourString = components.first,
              let hour = Int(hourString) else { return nil }
        return hour
    }
}

// MARK: - Place Suggestion Card

struct PlaceSuggestionCard: View {
    let place: Place
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 0) {
                // Photo
                ZStack(alignment: .topTrailing) {
                    if let imageUrl = place.image_cover ?? place.thumbnail_url,
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
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .appAccent : .white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
                .frame(height: 120)
                .clipped()
                
                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let category = place.categoryName {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.appAccent)
                    }
                    
                    if let desc = place.cleanDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                .padding(12)
            }
            .background(isSelected ? Color.appAccent.opacity(0.15) : Color(.systemGray6).opacity(0.3))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
        }
    }
}

// FlowLayout is already defined in FilterView.swift

// MARK: - Tag Chip

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(categoryEmoji(for: tag))
                Text(tag)
                    .font(.subheadline)
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appAccent : Color(.systemGray5).opacity(0.4))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func categoryEmoji(for tag: String) -> String {
        let lowered = tag.lowercased()
        if lowered.contains("church") || lowered.contains("cathedral") { return "⛪" }
        if lowered.contains("museum") { return "🏛️" }
        if lowered.contains("castle") || lowered.contains("fortress") { return "🏰" }
        if lowered.contains("park") || lowered.contains("garden") { return "🌳" }
        if lowered.contains("restaurant") || lowered.contains("food") { return "🍽️" }
        if lowered.contains("art") || lowered.contains("gallery") { return "🎨" }
        if lowered.contains("history") || lowered.contains("historic") { return "📜" }
        if lowered.contains("nature") || lowered.contains("natural") { return "🌿" }
        if lowered.contains("architecture") { return "🏗️" }
        if lowered.contains("underground") || lowered.contains("tunnel") { return "🕳️" }
        if lowered.contains("cemetery") || lowered.contains("tomb") { return "⚰️" }
        if lowered.contains("library") { return "📚" }
        if lowered.contains("tower") { return "🗼" }
        if lowered.contains("bridge") { return "🌉" }
        if lowered.contains("statue") || lowered.contains("monument") { return "🗽" }
        return "📍"
    }
}

#Preview {
    TripPlannerView(isPresented: .constant(true))
}
