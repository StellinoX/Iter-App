//
//  TripDetailView.swift
//  app ch3
//
//  Displays the generated trip itinerary with day-by-day tabs
//

import SwiftUI
import MapKit
import CoreLocation
import Supabase
import UniformTypeIdentifiers

struct TripDetailView: View {
    @State var trip: Trip
    @Binding var isPresented: Bool
    var isPlanning: Bool = true  // true = planning mode, false = viewing saved trip
    @State private var selectedDay = 0
    @State private var selectedRestaurantIds: Set<String> = []
    
    // Edit mode: place swap
    @State private var showingPlaceSwap = false
    @State private var swapActivityIndex: Int?
    @State private var swapDayIndex: Int?
    @State private var swapOriginalCoordinate: CLLocationCoordinate2D?
    @State private var swapOriginalPlace: Place?
    
    // Edit mode: time editing
    @State private var showingTimePicker = false
    @State private var editingActivityTime: Date = Date()
    @State private var editingActivityIndex: Int?
    @State private var editingDayIndex: Int?
    
    // Edit mode: place detail view
    @State private var showingPlaceDetail = false
    @State private var detailPlace: Place?
    
    // Edit mode: restaurant refresh
    @State private var refreshedRestaurants: [Int: [Int: MealSuggestion]] = [:] // [dayIndex: [mealIndex: suggestion]]
    @State private var isRefreshingRestaurants = false
    
    // Drag and drop state (viewing mode only)
    @State private var draggedActivityIndex: Int?
    
    // Route map view
    @State private var showingRouteMap = false
    @State private var routeMapDayIndex: Int = 0
    
    private let directionsService = DirectionsService()  // Current editing state
    
    var body: some View {
        VStack(spacing: 0) {
            // Trip header
            tripHeader
            
            // Day tabs
            dayTabs
            
            // Activities for selected day
            if selectedDay < trip.days.count {
                activitiesForDay(trip.days[selectedDay])
            }
        }
        .background(Color(hex: "0f0720"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ShareLink(item: generateShareText()) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.appAccent)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveTrip()
                    isPresented = false
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundColor(.appAccent)
                }
            }
        }
        .sheet(isPresented: $showingRouteMap) {
            DayRouteMapView(
                dayNumber: routeMapDayIndex + 1,
                cityName: trip.cityName,
                activities: trip.days[routeMapDayIndex].activities
            )
        }
    }
    
    // MARK: - Subviews
    
    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.appAccent)
                Text(dateRange)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("\(trip.numberOfDays) days in \(trip.cityName)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .onAppear {
            sanitizeTripData()
        }
    }
    
    private func sanitizeTripData() {
        Task {
            // Sanitize activities on load
            // Use SmartSanitizer for async geo-repair if needed
            for i in 0..<trip.days.count {
                for j in 0..<trip.days[i].activities.count {
                    // 1. Get current data
                    let currentName = trip.days[i].activities[j].placeName
                    let currentNotes = trip.days[i].activities[j].notes ?? ""
                    
                    // 2. Get coordinates if available
                    var coord: CLLocationCoordinate2D?
                    if let lat = trip.days[i].activities[j].coordinatesLat,
                       let lng = trip.days[i].activities[j].coordinatesLng {
                        coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                    
                    // 3. Sanitize Name
                    let cleanName = await SmartSanitizer.shared.sanitize(currentName, coordinate: coord)
                    
                    // 4. Sanitize Notes (no coordinate context usually needed for notes body, but passing nil is fine)
                    let cleanNotes = await SmartSanitizer.shared.sanitize(currentNotes, coordinate: nil)
                    
                    // 5. Apply changes on MainActor
                    await MainActor.run {
                        if trip.days[i].activities[j].placeName != cleanName {
                            trip.days[i].activities[j].placeName = cleanName
                        }
                        if trip.days[i].activities[j].notes != cleanNotes {
                            trip.days[i].activities[j].notes = cleanNotes
                        }
                    }
                }
            }
        }
    }
    
    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
    }
    
    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(0..<trip.days.count), id: \.self) { index in
                    Button {
                        withAnimation {
                            selectedDay = index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Day \(index + 1)")
                                .font(.subheadline.weight(selectedDay == index ? .bold : .medium))
                            
                            Text(dayDateString(trip.days[index].date))
                                .font(.caption2)
                        }
                        .foregroundColor(selectedDay == index ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedDay == index ? Color(hex: "BFFF00") : Color(.systemGray6).opacity(0.3))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private func dayDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func activitiesForDay(_ day: TripDay) -> some View {
        let dayIndex = trip.days.firstIndex(where: { $0.id == day.id }) ?? 0
        
        return ScrollView {
            VStack(spacing: 0) {
                // Day actions row
                HStack {
                    // Drag and drop hint (viewing mode only)
                    if !isPlanning && trip.days[dayIndex].activities.count > 1 {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text("Hold to reorder")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // View route button
                    if trip.days[dayIndex].activities.count >= 2 {
                        HStack(spacing: 8) {
                            // Optimize Route Button (Planning mode only)
                            if isPlanning {
                                Button {
                                    Task {
                                        await optimizeRoute(forDay: dayIndex)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.caption)
                                        Text("Optimize")
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // View route button
                            Button {
                                routeMapDayIndex = dayIndex
                                showingRouteMap = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                        .font(.caption)
                                    Text("View Route")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(.appAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appAccent.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Activities with reordering (only in viewing mode)
                ForEach(Array(trip.days[dayIndex].activities.enumerated()), id: \.element.id) { index, activity in
                    VStack(spacing: 0) {
                        // Transport indicator (if not first)
                        if index > 0 {
                            transportIndicator(activity)
                        }
                        
                        // Activity card with tap for options
                        Button {
                            showActivityOptions(activity: activity, dayIndex: dayIndex, activityIndex: index)
                        } label: {
                            activityCard(activity, dayIndex: dayIndex, activityIndex: index)
                        }
                        .buttonStyle(.plain)
                        // Drag and drop only in viewing mode (not planning)
                        .if(!isPlanning) { view in
                            view
                                .onDrag {
                                    draggedActivityIndex = index
                                    return NSItemProvider(object: String(index) as NSString)
                                }
                                .onDrop(of: [.text], delegate: ActivityDropDelegate(
                                    item: index,
                                    items: $trip.days[dayIndex].activities,
                                    draggedItem: $draggedActivityIndex,
                                    onComplete: {
                                        Task { await recalculateRoutes(forDay: dayIndex) }
                                    }
                                ))
                        }
                        
                        // Lunch suggestions (fixed, not draggable)
                        if let lunch = trip.days[dayIndex].lunchSuggestions, lunch.afterActivityIndex == index {
                            mealSuggestionSection(lunch, fromActivity: activity, dayIndex: dayIndex, mealType: .lunch)
                        }
                        
                        // Dinner suggestions (fixed, not draggable)
                        if let dinner = trip.days[dayIndex].dinnerSuggestions, dinner.afterActivityIndex == index {
                            mealSuggestionSection(dinner, fromActivity: activity, dayIndex: dayIndex, mealType: .dinner)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical)
        }
        .sheet(item: $selectedActivity) { activity in
            activityOptionsSheet(for: activity)
        }
        .sheet(isPresented: $showingPlaceSwap) {
            if let coordinate = swapOriginalCoordinate {
                PlaceSwapView(
                    originalPlace: swapOriginalPlace,
                    originalCoordinate: coordinate,
                    placesInPlan: getPlacesInPlan(),
                    onSelect: { newPlace in
                        swapActivity(with: newPlace)
                        if let dayIdx = swapDayIndex {
                            Task { await recalculateRoutes(forDay: dayIdx) }
                        }
                    }
                )
            } else {
                // Fallback when no coordinates - show message
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.5))
                    Text("Could not find coordinates for this place")
                        .foregroundColor(.white.opacity(0.7))
                    Button("Close") {
                        showingPlaceSwap = false
                    }
                    .foregroundColor(.appAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "0f0720"))
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                time: $editingActivityTime,
                onSave: {
                    if let dayIdx = editingDayIndex, let actIdx = editingActivityIndex {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        trip.days[dayIdx].activities[actIdx].startTime = formatter.string(from: editingActivityTime)
                    }
                    showingTimePicker = false
                },
                onCancel: {
                    showingTimePicker = false
                }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingPlaceDetail) {
            if let place = detailPlace {
                NavigationStack {
                    PlaceDetailView(place: place, userLocation: nil, viewModel: PlacesViewModel())
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showingPlaceDetail = false
                                }
                                .foregroundColor(.appAccent)
                            }
                        }
                }
            }
        }
        .onAppear {
            if isPlanning {
                autoSelectBestRestaurants()
            }
        }
    }
    
    // MARK: - Activity Options
    
    @State private var selectedActivity: TripActivity?
    @State private var selectedActivityDayIndex: Int?
    @State private var selectedActivityIndex: Int?
    
    private func showActivityOptions(activity: TripActivity, dayIndex: Int, activityIndex: Int) {
        selectedActivityDayIndex = dayIndex
        selectedActivityIndex = activityIndex
        selectedActivity = activity // This triggers the sheet
    }
    
    // Updated signature to take activity directly
    private func activityOptionsSheet(for activity: TripActivity) -> some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            VStack(spacing: 16) {
                Text(activity.placeName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                VStack(spacing: 12) {
                    // Modifica Orario
                    Button {
                        selectedActivity = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            editingDayIndex = selectedActivityDayIndex
                            editingActivityIndex = selectedActivityIndex
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            if let time = formatter.date(from: activity.startTime) {
                                editingActivityTime = time
                            }
                            showingTimePicker = true
                        }
                    } label: {
                        optionButton(icon: "clock", title: "Modifica Orario", color: .blue)
                    }
                    
                    // Cambia Luogo
                    Button {
                        selectedActivity = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            swapDayIndex = selectedActivityDayIndex
                            swapActivityIndex = selectedActivityIndex
                            if let placeId = activity.placeId {
                                Task {
                                    let place = await fetchPlaceById(placeId)
                                    swapOriginalPlace = place
                                    swapOriginalCoordinate = place?.coordinate
                                    showingPlaceSwap = true
                                }
                            } else {
                                showingPlaceSwap = true
                            }
                        }
                    } label: {
                        optionButton(icon: "mappin.and.ellipse", title: "Cambia Luogo", color: .orange)
                    }
                    
                    // Vedi Dettagli
                    if activity.placeId != nil {
                        Button {
                            selectedActivity = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let placeId = activity.placeId {
                                    Task {
                                        detailPlace = await fetchPlaceById(placeId)
                                        if detailPlace != nil {
                                            showingPlaceDetail = true
                                        }
                                    }
                                }
                            }
                        } label: {
                            optionButton(icon: "info.circle", title: "Vedi Dettagli", color: .purple)
                        }
                    }
                    
                    // Open in Maps
                    if activity.placeId != nil {
                        Button {
                            selectedActivity = nil
                            if let placeId = activity.placeId {
                                Task {
                                    if let place = await fetchPlaceById(placeId),
                                       let coord = place.coordinate {
                                        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                                        let mapItem = MKMapItem(location: location, address: nil)
                                        mapItem.name = activity.placeName
                                        mapItem.openInMaps()
                                    }
                                }
                            }
                        } label: {
                            optionButton(icon: "map", title: "Open in Maps", color: .green)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .background(Color(hex: "0f0720"))
        .presentationDetents([.height(350)])
    }
    
    private func optionButton(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Drag and Drop
    
    private func recalculateRoutes(forDay dayIndex: Int) async {
        let activities = trip.days[dayIndex].activities
        
        for i in 1..<activities.count {
            let prevActivity = activities[i - 1]
            let currentActivity = activities[i]
            
            // Get coordinates for both activities
            var prevCoord: CLLocationCoordinate2D?
            var currCoord: CLLocationCoordinate2D?
            
            if let prevId = prevActivity.placeId {
                prevCoord = await fetchPlaceById(prevId)?.coordinate
            }
            if let currId = currentActivity.placeId {
                currCoord = await fetchPlaceById(currId)?.coordinate
            }
            
            // Calculate route if we have both coordinates
            if let from = prevCoord, let to = currCoord {
                if let route = await directionsService.getWalkingRoute(from: from, to: to) {
                    trip.days[dayIndex].activities[i].transportDuration = route.duration
                    trip.days[dayIndex].activities[i].transportDetails = "📍 \(route.distance)"
                    trip.days[dayIndex].activities[i].transportMode = .walking
                } else {
                    // Fallback estimation
                    let distance = directionsService.calculateDistance(from: from, to: to)
                    trip.days[dayIndex].activities[i].transportDuration = directionsService.estimateWalkingDuration(distanceMeters: distance)
                    trip.days[dayIndex].activities[i].transportDetails = "📍 ~\(Int(distance))m"
                }
            }
        }
        
        // Clear transport info for first activity
        if !activities.isEmpty {
            trip.days[dayIndex].activities[0].transportDuration = nil
            trip.days[dayIndex].activities[0].transportDetails = nil
        }
    }
    
    private func fetchPlaceById(_ id: Int64) async -> Place? {
        do {
            let places: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .eq("id", value: String(id))
                .limit(1)
                .execute()
                .value
            
            if let place = places.first {
                print("DEBUG ENCODING - Raw Title from DB: \(place.title ?? "nil")")
                print("DEBUG ENCODING - Cleaned Title: \(place.displayName)")
            }
            
            return places.first
        } catch {
            print("Error fetching place: \(error)")
            return nil
        }
    }
    
    private func getPlacesInPlan() -> Set<Int64> {
        var ids: Set<Int64> = []
        for day in trip.days {
            for activity in day.activities {
                if let id = activity.placeId {
                    ids.insert(id)
                }
            }
        }
        return ids
    }
    
    private func swapActivity(with newPlace: Place) {
        guard let dayIdx = swapDayIndex, let actIdx = swapActivityIndex else { return }
        
        // Update the activity with new place
        trip.days[dayIdx].activities[actIdx].placeId = newPlace.id
        trip.days[dayIdx].activities[actIdx].placeName = newPlace.displayName
        trip.days[dayIdx].activities[actIdx].notes = newPlace.cleanDescription
        
        // Reset swap state
        swapDayIndex = nil
        swapActivityIndex = nil
        swapOriginalPlace = nil
        swapOriginalCoordinate = nil
    }
    
    private func mealSuggestionSection(_ meal: MealSuggestion, fromActivity: TripActivity, dayIndex: Int, mealType: MealSuggestion.MealType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal divider with type and time + refresh button in edit mode
            HStack(spacing: 8) {
                VStack {
                    Divider()
                        .frame(width: 2, height: 16)
                        .background(Color.orange.opacity(0.6))
                }
                .frame(width: 40)
                
                HStack(spacing: 6) {
                    Text(meal.mealType.emoji)
                    Text(meal.mealType.rawValue)
                        .font(.caption.weight(.medium))
                    Text(meal.mealType.suggestedTime)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .foregroundColor(.orange)
                
                Spacer()
                
                // Refresh button (always available)
                Button {
                    Task {
                        await refreshRestaurantsForMeal(dayIndex: dayIndex, mealType: mealType, nearActivity: fromActivity)
                    }
                } label: {
                    if isRefreshingRestaurants {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .disabled(isRefreshingRestaurants)
            }
            .padding(.top, 12)
            
            // Restaurant cards - show selection in planning mode, simple cards in viewing mode
            ForEach(meal.restaurants) { restaurant in
                if isPlanning {
                    // Planning mode: show selection toggle
                    RestaurantSuggestionCard(
                        restaurant: restaurant,
                        isSelected: selectedRestaurantIds.contains(restaurant.id),
                        showSelection: true,
                        onToggle: {
                            if selectedRestaurantIds.contains(restaurant.id) {
                                selectedRestaurantIds.remove(restaurant.id)
                            } else {
                                selectedRestaurantIds.insert(restaurant.id)
                            }
                        }
                    )
                } else {
                    // Viewing mode: simple card without selection
                    RestaurantSuggestionCard(
                        restaurant: restaurant,
                        isSelected: false,
                        showSelection: false,
                        onToggle: {}
                    )
                }
            }
        }
    }
    
    private func refreshRestaurantsForMeal(dayIndex: Int, mealType: MealSuggestion.MealType, nearActivity: TripActivity) async {
        isRefreshingRestaurants = true
        
        // Get coordinate from activity
        var coord: CLLocationCoordinate2D?
        if let placeId = nearActivity.placeId {
            let place = await fetchPlaceById(placeId)
            coord = place?.coordinate
        }
        
        guard let coordinate = coord else {
            isRefreshingRestaurants = false
            return
        }
        
        // Fetch new restaurants
        let newRestaurants = await directionsService.searchNearbyRestaurants(near: coordinate, radius: 500)
        
        // Update the appropriate meal suggestion
        if mealType == .lunch {
            trip.days[dayIndex].lunchSuggestions?.restaurants = newRestaurants
        } else {
            trip.days[dayIndex].dinnerSuggestions?.restaurants = newRestaurants
        }
        
        isRefreshingRestaurants = false
    }
    
    private func transportIndicator(_ activity: TripActivity) -> some View {
        HStack(spacing: 8) {
            VStack {
                Divider()
                    .frame(width: 2, height: 20)
                    .background(Color.gray.opacity(0.5))
            }
            .frame(width: 40)
            
            if let mode = activity.transportMode {
                HStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.caption)
                    if let duration = activity.transportDuration {
                        Text(duration)
                            .font(.caption2)
                    }
                    if let details = activity.transportDetails, !details.isEmpty {
                        Text("• \(details)")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 8)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func activityCard(_ activity: TripActivity, dayIndex: Int, activityIndex: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack {
                Text(activity.startTime)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appAccent)
                
                Text(activity.duration)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 40)
            
            // Activity details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.placeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                if let notes = activity.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Context menu hint
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func saveTrip() {
        // In planning mode, filter restaurants to keep only selected ones
        if isPlanning {
            for dayIndex in 0..<trip.days.count {
                if var lunch = trip.days[dayIndex].lunchSuggestions {
                    lunch.restaurants = lunch.restaurants.filter { selectedRestaurantIds.contains($0.id) }
                    trip.days[dayIndex].lunchSuggestions = lunch.restaurants.isEmpty ? nil : lunch
                }
                if var dinner = trip.days[dayIndex].dinnerSuggestions {
                    dinner.restaurants = dinner.restaurants.filter { selectedRestaurantIds.contains($0.id) }
                    trip.days[dayIndex].dinnerSuggestions = dinner.restaurants.isEmpty ? nil : dinner
                }
            }
        }
        // Save trip to UserDefaults
        UserDefaultsManager.shared.saveTrip(trip)
    }
    
    private func generateShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateRange = "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
        
        var text = "✈️ My \(trip.cityName) Trip\n"
        text += "📅 \(dateRange) (\(trip.numberOfDays) days)\n\n"
        
        for day in trip.days {
            text += "📍 Day \(day.dayNumber):\n"
            for activity in day.activities {
                text += "  • \(activity.placeName)"
                if !activity.startTime.isEmpty {
                    text += " (\(activity.startTime))"
                }
                text += "\n"
            }
            text += "\n"
        }
        
        text += "🗺️ Planned with Hidden Places App"
        
        return text
    }
    
    /// Open entire day itinerary in Apple Maps with all activities as waypoints
    private func openDayItineraryInMaps(dayIndex: Int) {
        guard dayIndex < trip.days.count else { return }
        let day = trip.days[dayIndex]
        
        // If activities have coordinates, use them directly
        var waypoints: [(name: String, coord: CLLocationCoordinate2D)] = []
        
        for activity in day.activities {
            if let coordinatesLat = activity.coordinatesLat,
               let coordinatesLng = activity.coordinatesLng {
                let coord = CLLocationCoordinate2D(latitude: coordinatesLat, longitude: coordinatesLng)
                waypoints.append((activity.placeName, coord))
            }
        }
        
        // If we have enough waypoints, open directly
        if waypoints.count >= 2 {
            openMapsWithWaypoints(waypoints)
            return
        }
        
        // Fallback: geocode by place names (for old trips without coordinates)
        Task {
            var geocodedWaypoints: [(name: String, coord: CLLocationCoordinate2D)] = []
            
            for activity in day.activities {
                if let coord = await geocodePlace(name: activity.placeName, city: trip.cityName) {
                    geocodedWaypoints.append((activity.placeName, coord))
                }
            }
            
            if geocodedWaypoints.count >= 2 {
                await MainActor.run {
                    openMapsWithWaypoints(geocodedWaypoints)
                }
            } else if geocodedWaypoints.count == 1 {
                await MainActor.run {
                    let location = CLLocation(latitude: geocodedWaypoints[0].coord.latitude, longitude: geocodedWaypoints[0].coord.longitude)
                    let mapItem = MKMapItem(location: location, address: nil)
                    mapItem.name = geocodedWaypoints[0].name
                    mapItem.openInMaps()
                }
            }
        }
    }
    
    private func openMapsWithWaypoints(_ waypoints: [(name: String, coord: CLLocationCoordinate2D)]) {
        guard waypoints.count >= 2 else { return }
        
        // Build Apple Maps URL with all waypoints for a proper route
        // Format: maps://?saddr=lat,lng&daddr=lat,lng+to:lat,lng+to:lat,lng...&dirflg=w
        let startCoord = waypoints.first!.coord
        let endCoord = waypoints.last!.coord
        
        // Build intermediate waypoints as "+to:" separated coordinates
        var waypointStrings: [String] = []
        for (index, waypoint) in waypoints.enumerated() {
            if index > 0 && index < waypoints.count - 1 {
                waypointStrings.append("\(waypoint.coord.latitude),\(waypoint.coord.longitude)")
            }
        }
        
        var urlString = "maps://?saddr=\(startCoord.latitude),\(startCoord.longitude)"
        urlString += "&daddr=\(endCoord.latitude),\(endCoord.longitude)"
        
        // Add intermediate waypoints
        for waypointCoord in waypointStrings {
            urlString += "+to:\(waypointCoord)"
        }
        
        // dirflg=w for walking directions
        urlString += "&dirflg=w"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to standard MKMapItem approach
            fallbackOpenMaps(waypoints)
        }
    }
    
    private func fallbackOpenMaps(_ waypoints: [(name: String, coord: CLLocationCoordinate2D)]) {
        var mapItems: [MKMapItem] = []
        for waypoint in waypoints {
            let location = CLLocation(latitude: waypoint.coord.latitude, longitude: waypoint.coord.longitude)
            let mapItem = MKMapItem(location: location, address: nil)
            mapItem.name = waypoint.name
            mapItems.append(mapItem)
        }
        
        MKMapItem.openMaps(
            with: mapItems,
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
                MKLaunchOptionsShowsTrafficKey: false
            ]
        )
    }
    
    private func geocodePlace(name: String, city: String) async -> CLLocationCoordinate2D? {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(name), \(city)"
        
        let search = MKLocalSearch(request: searchRequest)
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            print("❌ Geocoding failed for \(name): \(error)")
            return nil
        }
    }
}

// MARK: - Restaurant Suggestion Card

struct RestaurantSuggestionCard: View {
    let restaurant: RestaurantSuggestion
    let isSelected: Bool
    let showSelection: Bool
    let onToggle: () -> Void
    @State private var showActions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card - tap to toggle actions
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showActions.toggle()
                }
            } label: {
                mainCardContent
            }
            
            // Expandable action buttons
            if showActions {
                actionButtons
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected && showSelection ? Color(hex: "a855f7").opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private var mainCardContent: some View {
        HStack(spacing: 12) {
            // Restaurant icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                Text("🍽️")
                    .font(.title2)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(restaurant.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !restaurant.priceLevelString.isEmpty {
                        Text(restaurant.priceLevelString)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(restaurant.category)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(restaurant.formattedDistance)
                        .font(.caption)
                        .foregroundColor(Color(hex: "a855f7"))
                }
                
                if let address = restaurant.address, !address.isEmpty {
                    Text(address)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Expand/collapse indicator + selection button (if in planning mode)
            HStack(spacing: 12) {
                Image(systemName: showActions ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.caption)
                
                if showSelection {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            onToggle()
                        }
                    } label: {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "a855f7"))
                                .font(.title2)
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.title2)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Open in Apple Maps
            Button {
                restaurant.openInMaps()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                    Text("Maps")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "a855f7"))
                .cornerRadius(8)
            }
            
            // Call (if phone available)
            if restaurant.phoneNumber != nil {
                Button {
                    restaurant.callPhone()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                        Text("Call")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            
            // Website (if available)
            if restaurant.url != nil {
                Button {
                    restaurant.openWebsite()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("Web")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    @Binding var time: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("Edit Time")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                }
                .fontWeight(.semibold)
                .foregroundColor(.appAccent)
            }
            .padding()
            
            // Time picker
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            
            Spacer()
        }
        .background(Color(hex: "0f0720"))
    }
}

// MARK: - Activity Drop Delegate

struct ActivityDropDelegate: DropDelegate {
    let item: Int
    @Binding var items: [TripActivity]
    @Binding var draggedItem: Int?
    let onComplete: () -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onComplete()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item else { return }
        
        let from = draggedItem
        let to = item
        
        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        
        self.draggedItem = to
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Auto Selection Logic
extension TripDetailView {
    /// Automatically select the first (best) restaurant if none is selected
    func autoSelectBestRestaurants() {
        for day in trip.days {
            // Lunch
            if let lunch = day.lunchSuggestions, let first = lunch.restaurants.first {
                // If we haven't selected any restaurant for this meal yet...
                // (Checking if any restaurant ID from this suggestion list is in selected set)
                let hasSelection = lunch.restaurants.contains { selectedRestaurantIds.contains($0.id) }
                if !hasSelection {
                    selectedRestaurantIds.insert(first.id)
                }
            }
            
            // Dinner
            if let dinner = day.dinnerSuggestions, let first = dinner.restaurants.first {
                // Check if any restaurant from this list is already selected
                let hasSelection = dinner.restaurants.contains { selectedRestaurantIds.contains($0.id) }
                if !hasSelection {
                    selectedRestaurantIds.insert(first.id)
                }
            }
        }
    }
    
    /// Optimize the route for a specific day by reordering activities geographically
    /// Uses a Nearest Neighbor greedy algorithm
    func optimizeRoute(forDay dayIndex: Int) async {
        guard dayIndex < trip.days.count else { return }
        let activities = trip.days[dayIndex].activities
        guard activities.count > 2 else { return } // No need to optimize if < 3 places
        
        // Fetch coordinates for all places
        var placeCoordinates: [Int: CLLocationCoordinate2D] = [:] // [ActivityIndex : Coord]
        
        for (index, activity) in activities.enumerated() {
            if let placeId = activity.placeId,
               let place = await fetchPlaceById(placeId),
               let coord = place.coordinate {
                placeCoordinates[index] = coord
            }
        }
        
        // Start with the first activity (assuming it's the desired start point/closest to hotel)
        // Or we could try to find the one closest to the hotel if we had hotel coord here
        var optimizedActivities: [TripActivity] = []
        var remainingIndices = Array(0..<activities.count)
        
        // Always keep the first one as start
        if let firstIndex = remainingIndices.first {
            optimizedActivities.append(activities[firstIndex])
            remainingIndices.removeFirst()
        }
        
        // Greedy Nearest Neighbor
        var currentCoord = placeCoordinates[0] // Start coord
        
        while !remainingIndices.isEmpty {
            guard let current = currentCoord else {
                // If we lost track of coordinates, just append the rest as is
                for idx in remainingIndices {
                    optimizedActivities.append(activities[idx])
                }
                break
            }
            
            // Find closest remaining activity
            var closestIndex: Int?
            var minDistance: Double = .infinity
            
            for idx in remainingIndices {
                if let nextCoord = placeCoordinates[idx] {
                    let dist = DirectionsService().calculateDistance(from: current, to: nextCoord)
                    if dist < minDistance {
                        minDistance = dist
                        closestIndex = idx
                    }
                }
            }
            
            if let closest = closestIndex {
                optimizedActivities.append(activities[closest])
                currentCoord = placeCoordinates[closest]
                remainingIndices.removeAll { $0 == closest }
            } else {
                // Should not happen if coordinates are valid, but safe fallback
                if let firstRemaining = remainingIndices.first {
                    optimizedActivities.append(activities[firstRemaining])
                    remainingIndices.removeFirst()
                }
            }
        }
        
        // Apply optimization
        withAnimation {
            trip.days[dayIndex].activities = optimizedActivities
        }
        
        // Recalculate transport times
        await recalculateRoutes(forDay: dayIndex)
    }
}

#Preview {
    NavigationStack {
        TripDetailView(
            trip: Trip(cityName: "Roma", startDate: Date(), endDate: Date().addingTimeInterval(3*24*60*60)),
            isPresented: .constant(true)
        )
    }
}
