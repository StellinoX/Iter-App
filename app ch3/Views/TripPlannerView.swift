//
//  TripPlannerView.swift
//  app ch3
//
//  Trip planning flow: select city, dates, places, generate AI itinerary
//

import SwiftUI
import MapKit
import Supabase
import CoreLocation
import Combine

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
    
    // Tag/Category filter - using macro-categories
    @State private var selectedCategories: Set<CategoryGroup> = []
    @State private var isLoadingTags = false
    
    // Food budget (1 = €, 2 = €€, 3 = €€€, 4 = €€€€)
    @State private var foodBudget: Int = 2
    
    // Max distance between places (in km)
    @State private var maxDistanceKm: Double = 2.0
    
    // Smart Preferences
    enum TravelPace: String, CaseIterable, Identifiable {
        case relaxed = "Relaxed 🐢"
        case balanced = "Balanced 🚶"
        case packed = "Packed 🏃"
        
        var id: String { rawValue }
        
        var placesPerDay: Int {
            switch self {
            case .relaxed: return 2
            case .balanced: return 4
            case .packed: return 6
            }
        }
    }
    
    enum RestaurantVibe: String, CaseIterable, Identifiable {
        case casual = "Casual 🍝"
        case romantic = "Romantic 🍷"
        case streetFood = "Street Food 🥪"
        case local = "Local 🥗"
        
        var id: String { rawValue }
        
        var searchKeywords: String {
            switch self {
            case .casual: return "Trattoria Pizzeria"
            case .romantic: return "Romantic Restaurant"
            case .streetFood: return "Street Food"
            case .local: return "Traditional Restaurant"
            }
        }
    }
    
    @State private var selectedPace: TravelPace = .balanced
    @State private var selectedVibe: RestaurantVibe = .casual
    
    @StateObject private var aiService = AIService()
    @StateObject private var hotelCompleter = HotelSearchCompleter()
    private let directionsService = DirectionsService()
    
    private var requiredPlaces: Int {
        calculateDays() * selectedPace.placesPerDay
    }
    
    enum PlannerStep {
        case city, dates, generating, result
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
                case .generating:
                    generatingView
                case .result:
                    if let trip = generatedTrip {
                        TripDetailView(trip: trip, isPresented: $isPresented)
                    }
                }
            }
            
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
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch step {
        case .city: return "Choose Destination"
        case .dates: return "Plan Your Trip"
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
        ScrollView {
            VStack(spacing: 20) {
                // City selected
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.appAccent)
                    
                    VStack(alignment: .leading) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
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
                VStack(spacing: 12) {
                    HStack {
                        Text("Start Date")
                            .foregroundColor(.white)
                        Spacer()
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.appAccent)
                            .environment(\.locale, Locale(identifier: "en_GB"))
                    }
                    
                    HStack {
                        Text("End Date")
                            .foregroundColor(.white)
                        Spacer()
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.appAccent)
                            .environment(\.locale, Locale(identifier: "en_GB"))
                    }
                    
                    // Duration indicator
                    let days = calculateDays()
                    Text("\(days) \(days == 1 ? "day" : "days") trip")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.appAccent)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                
                // Hotel input with autocomplete
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are you staying?")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 0) {
                        // Search field
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.white.opacity(0.5))
                            TextField("Hotel/Airbnb address", text: Binding(
                                get: { hotelAddress },
                                set: { newValue in
                                    hotelAddress = newValue
                                    hotelCompleter.search(newValue, in: selectedCity)
                                }
                            ))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            
                            if !hotelAddress.isEmpty {
                                Button {
                                    hotelAddress = ""
                                    hotelCompleter.clear()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(hotelCompleter.results.isEmpty ? 12 : 0)
                        .cornerRadius(12, corners: [.topLeft, .topRight])
                        
                        // Autocomplete results
                        if !hotelCompleter.results.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(hotelCompleter.results.prefix(5), id: \.self) { result in
                                    Button {
                                        hotelAddress = result.title
                                        if !result.subtitle.isEmpty {
                                            hotelAddress += ", " + result.subtitle
                                        }
                                        hotelCompleter.clear()
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin.circle")
                                                .foregroundColor(.appAccent)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                if !result.subtitle.isEmpty {
                                                    Text(result.subtitle)
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                    }
                                    
                                    if result != hotelCompleter.results.prefix(5).last {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                        }
                    }
                }
                
                // Category selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you want to see?")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CategoryGroup.allCases) { category in
                            Button {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                        .foregroundColor(selectedCategories.contains(category) ? .black : category.color)
                                    
                                    Text(category.rawValue)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(selectedCategories.contains(category) ? .black : .white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(selectedCategories.contains(category) ? Color.appAccent : Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Quick select buttons
                    HStack {
                        Button("Select All") {
                            selectedCategories = Set(CategoryGroup.allCases)
                        }
                        .font(.caption)
                        .foregroundColor(.appAccent)
                        
                        Spacer()
                        
                        Button("Clear") {
                            selectedCategories.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Travel Style Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Travel Style")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    // Pace
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pace")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Picker("Pace", selection: $selectedPace) {
                            ForEach(TravelPace.allCases) { pace in
                                Text(pace.rawValue).tag(pace)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(.appAccent)
                    }
                    
                    // Restaurant Vibe
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restaurant Vibe")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Picker("Vibe", selection: $selectedVibe) {
                            ForEach(RestaurantVibe.allCases) { vibe in
                                Text(vibe.rawValue).tag(vibe)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(.appAccent)
                    }
                }

                // Food Budget selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Food Budget")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { level in
                            Button {
                                withAnimation {
                                    foodBudget = level
                                }
                            } label: {
                                Text(String(repeating: "€", count: level))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(foodBudget == level ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(foodBudget == level ? Color.appAccent : Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Text(budgetDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Max distance slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Distance Between Places")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(String(format: "%.1f", maxDistanceKm)) km")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.appAccent)
                    }
                    
                    Slider(value: $maxDistanceKm, in: 0.5...5.0, step: 0.5)
                        .tint(.appAccent)
                    
                    Text("Places farther than this will be grouped on different days")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer().frame(height: 20)
                
                // Generate button
                Button {
                    startAutoGeneration()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate Itinerary")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCategories.isEmpty ? Color.gray : Color(hex: "BFFF00"))
                    .cornerRadius(16)
                }
                .disabled(selectedCategories.isEmpty)
            }
            .padding()
        }
    }
    
    
    // NOTE: tagFilterView removed - categories now integrated in dateSelectionView
    
    
    
    // NOTE: aiSelectionView removed - places now auto-selected by AI
    
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
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
    }
    
    private var budgetDescription: String {
        switch foodBudget {
        case 1: return "Budget-friendly street food & casual dining"
        case 2: return "Mid-range restaurants & trattorias"
        case 3: return "Upscale dining experiences"
        case 4: return "Fine dining & Michelin-starred restaurants"
        default: return ""
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
            case .result: step = .dates
            default: break
            }
        }
    }
    
    // NOTE: goToTagFilter and goToAISelection removed - now using startAutoGeneration directly
    
    private func loadNextSuggestions() async {
        isLoadingSuggestions = true
        
        // Filter out already selected places AND currently suggested places
        let selectedIds = Set(selectedPlaces.map { $0.id })
        let suggestedIds = Set(suggestedPlaces.map { $0.id })
        let excludedIds = selectedIds.union(suggestedIds)
        
        let availablePlaces = allPlaces.filter { place in
            !excludedIds.contains(place.id)
        }
        
        guard !availablePlaces.isEmpty else {
            // No more places available - shuffle and show random
            suggestedPlaces = Array(allPlaces.filter { !selectedIds.contains($0.id) }.shuffled().prefix(4))
            isLoadingSuggestions = false
            return
        }
        
        // Get AI suggestions
        let newSuggestedIds = await aiService.suggestNextPlaces(
            availablePlaces: availablePlaces,
            selectedPlaces: selectedPlaces,
            hotelAddress: hotelAddress,
            count: 4
        )
        
        // Map IDs to places
        if !newSuggestedIds.isEmpty {
            suggestedPlaces = newSuggestedIds.compactMap { id in
                availablePlaces.first(where: { $0.id == id })
            }
        } else {
            // Fallback: show first 4 available places
            suggestedPlaces = Array(availablePlaces.prefix(4))
        }
        
        isLoadingSuggestions = false
    }
    
    /// Automatically fetch places, filter by categories, and generate optimized itinerary
    private func startAutoGeneration() {
        withAnimation {
            step = .generating
        }
        
        Task {
            // 1. Fetch all places for the city
            let allCityPlaces = await fetchPlacesForCity()
            print("📍 Fetched \(allCityPlaces.count) places for \(selectedCity)")
            
            // 2. Filter by selected categories
            let filteredPlaces = allCityPlaces.filter { place in
                CategoryGroup.anyMatch(groups: selectedCategories, tagsTitle: place.tags_title)
            }
            print("📍 Filtered to \(filteredPlaces.count) places matching categories")
            
            // 3. Sort by distance from hotel if provided
            var placesToUse: [Place]
            if !hotelAddress.isEmpty {
                placesToUse = await sortPlacesByDistanceFromHotel(filteredPlaces)
            } else {
                placesToUse = filteredPlaces.shuffled()
            }
            
            // 4. Filter out places that are too far from each other
            let maxDistanceMeters = maxDistanceKm * 1000
            placesToUse = filterPlacesByProximity(placesToUse, maxDistance: maxDistanceMeters)
            print("📍 After distance filter: \(placesToUse.count) places within \(maxDistanceKm)km of each other")
            
            // 5. Select optimal number of places (4 per day + some extras for AI to choose from)
            let requiredCount = calculateDays() * selectedPace.placesPerDay
            let selectedCount = min(requiredCount * 2, placesToUse.count) // Give AI 2x places to choose from
            selectedPlaces = Array(placesToUse.prefix(selectedCount))
            
            print("📍 Selected \(selectedPlaces.count) places for AI to optimize")
            
            // 5. Generate itinerary with AI
            await generateItineraryWithPlaces()
        }
    }
    
    private func generateItineraryWithPlaces() async {
        // Create trip structure
        var trip = Trip(cityName: selectedCity, startDate: startDate, endDate: endDate)
        
        // Generate with AI using selected places and hotel
        if let aiDays = await aiService.generateItinerary(
            city: selectedCity,
            days: calculateDays(),
            places: selectedPlaces,
            hotelAddress: hotelAddress,
            pace: selectedPace.rawValue,
            vibe: selectedVibe.rawValue
        ) {
            var updatedDays = aiDays
            
            for (dayIndex, day) in aiDays.enumerated() {
                // Track coordinates for this day's activities
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
                            
                            if let route = await directionsService.getWalkingRoute(from: prevCoord, to: coord) {
                                updatedDays[dayIndex].activities[activityIndex].transportDuration = route.duration
                                updatedDays[dayIndex].activities[activityIndex].transportDetails = "📍 \(route.distance)"
                            } else {
                                let distance = directionsService.calculateDistance(from: prevCoord, to: coord)
                                let duration = directionsService.estimateWalkingDuration(distanceMeters: distance)
                                updatedDays[dayIndex].activities[activityIndex].transportDuration = duration
                                updatedDays[dayIndex].activities[activityIndex].transportDetails = "📍 ~\(Int(distance))m"
                            }
                        }
                    }
                }
                
                // Find lunch slot
                var lunchActivityIndex: Int?
                var lunchCoord: CLLocationCoordinate2D?
                for item in dayCoordinates {
                    if let hour = parseHour(from: item.time), hour >= 11 && hour <= 13 {
                        lunchActivityIndex = item.index
                        lunchCoord = item.coord
                        break
                    }
                }
                
                // Find dinner slot
                var dinnerActivityIndex: Int?
                var dinnerCoord: CLLocationCoordinate2D?
                for item in dayCoordinates.reversed() {
                    if let hour = parseHour(from: item.time), hour >= 18 && hour <= 21 {
                        dinnerActivityIndex = item.index
                        dinnerCoord = item.coord
                        break
                    }
                }
                
                // Search for lunch restaurants (with budget filter)
                if let idx = lunchActivityIndex, let coord = lunchCoord {
                    // Use selected vibe keywords for search
                    let allRestaurants = await directionsService.searchNearbyRestaurants(
                        near: coord, 
                        radius: 800,
                        query: selectedVibe.searchKeywords + " restaurant"
                    )
                    // Filter by budget (allow ±1 level tolerance)
                    let filteredRestaurants = allRestaurants.filter { restaurant in
                        guard let level = restaurant.priceLevel else { return true } // Include if no price info
                        return abs(level - foodBudget) <= 1
                    }
                    let restaurants = filteredRestaurants.isEmpty ? allRestaurants : filteredRestaurants
                    if !restaurants.isEmpty {
                        updatedDays[dayIndex].lunchSuggestions = MealSuggestion(
                            afterActivityIndex: idx,
                            restaurants: Array(restaurants.prefix(3)),
                            mealType: .lunch
                        )
                    }
                }
                
                // Search for dinner restaurants (with budget filter)
                if let idx = dinnerActivityIndex, let coord = dinnerCoord {
                    // Use selected vibe keywords for search
                    let allRestaurants = await directionsService.searchNearbyRestaurants(
                        near: coord, 
                        radius: 800, 
                        query: selectedVibe.searchKeywords + " restaurant"
                    )
                    // Filter by budget (allow ±1 level tolerance)
                    let filteredRestaurants = allRestaurants.filter { restaurant in
                        guard let level = restaurant.priceLevel else { return true }
                        return abs(level - foodBudget) <= 1
                    }
                    let restaurants = filteredRestaurants.isEmpty ? allRestaurants : filteredRestaurants
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
        } else {
            // Fallback: create basic itinerary
            let placesPerDay = selectedPlaces.count / calculateDays()
            for dayIndex in 0..<calculateDays() {
                let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: startDate) ?? startDate
                var tripDay = TripDay(dayNumber: dayIndex + 1, date: date)
                
                let startIdx = dayIndex * placesPerDay
                let endIdx = min(startIdx + placesPerDay, selectedPlaces.count)
                let dayPlaces = Array(selectedPlaces[startIdx..<endIdx])
                
                let times = ["09:00", "12:00", "15:00", "18:00"]
                for (idx, place) in dayPlaces.prefix(4).enumerated() {
                    var activity = TripActivity(
                        placeName: place.displayName,
                        startTime: times[idx],
                        duration: "2h",
                        placeId: place.id
                    )
                    activity.notes = place.description
                    tripDay.activities.append(activity)
                }
                
                trip.days.append(tripDay)
            }
        }
        
        // Save trip
        UserDefaultsManager.shared.saveTrip(trip)
        generatedTrip = trip
        
        await MainActor.run {
            withAnimation {
                step = .result
            }
        }
    }
    
    private func fetchPlacesForCity() async -> [Place] {
        print("🗺️ Fetching ALL places for city: \(selectedCity)")
        
        do {
            let client = SupabaseManager.shared.client
            
            // First try to search by city name - NO LIMIT to get all places
            var response: [Place] = try await client
                .from("places")
                .select()
                .ilike("city", pattern: "%\(selectedCity)%")
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
                    .execute()
                    .value
                
                print("🗺️ Found \(response.count) places by coordinates")
            }
            
            // If hotel address is provided, geocode and sort by distance
            if !hotelAddress.isEmpty {
                response = await sortPlacesByDistanceFromHotel(response)
            }
            
            return response
        } catch {
            print("❌ Error fetching places for city: \(error)")
            return []
        }
    }
    
    /// Geocode hotel address and sort places by distance from hotel
    private func sortPlacesByDistanceFromHotel(_ places: [Place]) async -> [Place] {
        // Use MKLocalSearch for geocoding (iOS 26+)
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(hotelAddress), \(selectedCity)"
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            guard let location = response.mapItems.first?.location else {
                print("⚠️ Could not geocode hotel address")
                return places
            }
            
            let hotelCoord = location.coordinate
            print("🏨 Hotel geocoded: \(hotelCoord.latitude), \(hotelCoord.longitude)")
            
            // Sort places by distance from hotel
            let sortedPlaces = places.sorted { place1, place2 in
                let dist1 = distanceFrom(hotelCoord, to: place1)
                let dist2 = distanceFrom(hotelCoord, to: place2)
                return dist1 < dist2
            }
            
            return sortedPlaces
        } catch {
            print("⚠️ Geocoding error: \(error)")
            return places
        }
    }
    
    /// Calculate distance between a coordinate and a place
    private func distanceFrom(_ coord: CLLocationCoordinate2D, to place: Place) -> Double {
        guard let placeCoord = place.coordinate else { return Double.infinity }
        let from = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let to = CLLocation(latitude: placeCoord.latitude, longitude: placeCoord.longitude)
        return from.distance(from: to)
    }
    
    /// Parse hour from time string like "09:00" or "14:30"
    private func parseHour(from timeString: String) -> Int? {
        let components = timeString.split(separator: ":")
        guard let hourString = components.first,
              let hour = Int(hourString) else { return nil }
        return hour
    }
    
    /// Filter places to keep only those within maxDistance of a central point (hotel or first place)
    /// This prevents "drifting" where places A->B->C are close but A->C is far.
    private func filterPlacesByProximity(_ places: [Place], maxDistance: Double) -> [Place] {
        guard places.count > 1 else { return places }
        guard let centerPlace = places.first, let centerCoord = centerPlace.coordinate else { return places }
        
        var result: [Place] = [centerPlace]
        
        // Check all other places against the center
        for place in places.dropFirst() {
            guard place.coordinate != nil else { continue }
            
            let dist = distanceFrom(centerCoord, to: place)
            if dist <= maxDistance {
                result.append(place)
            }
        }
        
        print("📍 Proximity filter: kept \(result.count) of \(places.count) places (within \(maxDistance/1000)km of center)")
        return result
    }
}

// MARK: - Hotel Address Autocomplete

@MainActor
class HotelSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    
    private let completer = MKLocalSearchCompleter()
    private var currentCity = ""
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }
    
    func search(_ query: String, in city: String) {
        guard !query.isEmpty else {
            clear()
            return
        }
        
        currentCity = city
        isSearching = true
        
        // Append city name to query for better local results
        let searchQuery = query.contains(city) ? query : "\(query) \(city)"
        completer.queryFragment = searchQuery
    }
    
    func clear() {
        results = []
        isSearching = false
    }
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Filter to show hotels, addresses, and lodging
            self.results = completer.results.filter { result in
                let title = result.title.lowercased()
                let subtitle = result.subtitle.lowercased()
                // Include hotels, B&Bs, apartments, addresses
                return title.contains("hotel") ||
                       title.contains("b&b") ||
                       title.contains("airbnb") ||
                       title.contains("apartment") ||
                       title.contains("residence") ||
                       title.contains("hostel") ||
                       title.contains("inn") ||
                       title.contains("via ") ||
                       title.contains("piazza ") ||
                       title.contains("corso ") ||
                       subtitle.contains(self.currentCity.lowercased()) ||
                       !subtitle.isEmpty // Keep results with location info
            }
            self.isSearching = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("Hotel search error: \(error.localizedDescription)")
            self.isSearching = false
        }
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
                            .foregroundColor(.white.opacity(0.7))
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

// MARK: - Corner Radius Extension moved to shared location (or relying on PlaceDetailView version)
