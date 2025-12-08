//
//  PlacesViewModel.swift
//  app ch3
//
//  ViewModel per gestire il caricamento dei luoghi da Supabase
//

import Foundation
import CoreLocation
import Combine
import Supabase
import PostgREST
import MapKit

struct EquatableRegion: Equatable {
    let region: MKCoordinateRegion
    
    static func == (lhs: EquatableRegion, rhs: EquatableRegion) -> Bool {
        lhs.region.center.latitude == rhs.region.center.latitude &&
        lhs.region.center.longitude == rhs.region.center.longitude &&
        lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
        lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadedRegion: MKCoordinateRegion?
    @Published var regionToRecenter: EquatableRegion?
    @Published var searchText = ""
    @Published var clusteredItems: [MapItem] = []
    
    // Regione corrente per aggiornare il clustering dopo il caricamento
    private var currentDisplayRegion: MKCoordinateRegion?
    
    @Published var selectedCategories: Set<String> = []
    @Published var favoriteIDs: Set<Int64> = []
    @Published var visitedIDs: Set<Int64> = []
    @Published var favoritePlacesFull: [Place] = [] // Full Place objects for favorites
    
    // Advanced filter settings
    @Published var currentSortOrder: SortOrder = .distance
    @Published var maxDistanceFilter: Double?
    @Published var showOnlyUnvisited: Bool = false
    var userLocationForFilter: CLLocationCoordinate2D?
    
    private let userDefaults = UserDefaultsManager.shared
    private var loadingTask: Task<Void, Never>?
    
    // City-based statistics
    @Published var currentCity: String?
    @Published var cityTotalPlaces: Int = 0
    @Published var cityCountByCategory: [String: Int] = [:]
    
    init() {
        // Carica dati persistenti
        self.selectedCategories = userDefaults.getSelectedCategories()
        self.favoriteIDs = userDefaults.getFavorites()
        self.visitedIDs = userDefaults.getVisited()
    }
    
    /// Detect city from map center using MKLocalSearch
    func detectCity(from coordinate: CLLocationCoordinate2D) async {
        // Use MKLocalSearch for reverse geocoding
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "point of interest"
        searchRequest.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            if let firstItem = response.mapItems.first {
                let placemark = firstItem.placemark
                let city = placemark.locality ?? placemark.administrativeArea ?? placemark.country
                if city != currentCity {
                    currentCity = city
                    if let cityName = city {
                        await fetchCityStats(city: cityName)
                    }
                }
            }
        } catch {
            print("Geocoding error: \(error)")
        }
    }
    
    /// Fetch total place count for a specific city from Supabase
    func fetchCityStats(city: String) async {
        do {
            let client = SupabaseManager.shared.client
            
            // Fetch all places for this city to get accurate count
            let response: [Place] = try await client
                .from("places")
                .select()
                .ilike("city", pattern: "%\(city)%")
                .execute()
                .value
            
            cityTotalPlaces = response.count
            
            // Count by category
            var categoryCounts: [String: Int] = [:]
            for place in response {
                if let category = place.categoryName {
                    categoryCounts[category, default: 0] += 1
                }
            }
            cityCountByCategory = categoryCounts
            
        } catch {
            print("Error fetching city stats: \(error)")
        }
    }
    
    /// Get visited count for current city
    var cityVisitedCount: Int {
        places.filter { 
            $0.city?.localizedCaseInsensitiveContains(currentCity ?? "") == true &&
            visitedIDs.contains($0.id)
        }.count
    }
    
    /// Get favorite count for current city
    var cityFavoriteCount: Int {
        places.filter {
            $0.city?.localizedCaseInsensitiveContains(currentCity ?? "") == true &&
            favoriteIDs.contains($0.id)
        }.count
    }
    
    // MARK: - Regional Statistics
    
    struct RegionalStats {
        var worldTotal: Int = 0
        var europeTotal: Int = 0
        var americasTotal: Int = 0
        var asiaTotal: Int = 0
    }
    
    @Published var regionalStats = RegionalStats()
    
    // Dynamic lists from DB
    @Published var dbCountries: [String] = []
    @Published var dbCategories: [String] = []
    
    // Country lists for each region (will be filtered by what's in DB)
    private let europeCountries = ["Italy", "Italia", "France", "Francia", "Spain", "España", "Germany", "Deutschland", "UK", "United Kingdom", "Portugal", "Greece", "Netherlands", "Belgium", "Austria", "Switzerland", "Poland", "Czech", "Hungary", "Croatia", "Slovenia", "Romania", "Bulgaria", "Sweden", "Norway", "Denmark", "Finland", "Ireland"]
    
    private let americasCountries = ["USA", "United States", "Canada", "Mexico", "Brasil", "Brazil", "Argentina", "Chile", "Colombia", "Peru", "Venezuela", "Cuba", "Ecuador", "Bolivia", "Uruguay", "Paraguay", "Costa Rica", "Panama"]
    
    private let asiaCountries = ["China", "Japan", "Russia", "India", "Thailand", "Vietnam", "Indonesia", "Malaysia", "Singapore", "Korea", "Taiwan", "Philippines", "Turkey", "Israel", "UAE", "Saudi Arabia", "Iran", "Pakistan", "Kazakhstan", "Mongolia", "Nepal"]
    
    /// Fetch distinct countries and categories from DB to see what's available
    func fetchDistinctValues() async {
        print("🔍 Fetching distinct values from DB...")
        
        do {
            let client = SupabaseManager.shared.client
            
            // Get sample of places to extract unique countries and tags
            let sample: [Place] = try await client
                .from("places")
                .select("country, tags_title")
                .limit(30000)
                .execute()
                .value
            
            // Extract unique countries
            var countries = Set<String>()
            var categories = Set<String>()
            
            for place in sample {
                if let country = place.country, !country.isEmpty {
                    countries.insert(country)
                }
                if let tags = place.tags_title, !tags.isEmpty {
                    categories.insert(tags)
                }
            }
            
            dbCountries = countries.sorted()
            dbCategories = categories.sorted()
            
            print("🌍 Countries in DB (\(dbCountries.count)):")
            for country in dbCountries {
                print("   - \(country)")
            }
            
            print("🏷️ Categories/Tags in DB (\(dbCategories.count)):")
            for category in dbCategories {
                print("   - \(category)")
            }
            
        } catch {
            print("❌ Error fetching distinct values: \(error)")
        }
    }
    
    /// Fetch regional statistics from Supabase using simple count queries
    func fetchRegionalStats() async {
        print("📊 Starting fetchRegionalStats...")
        
        do {
            let client = SupabaseManager.shared.client
            
            // World total
            let worldCount = try await client
                .from("places")
                .select("*", head: true, count: .exact)
                .execute()
                .count ?? 0
            
            print("📊 World total: \(worldCount)")
            
            // Europe count - filter by European countries
            let europeFilter = europeCountries.map { "country.ilike.%\($0)%" }.joined(separator: ",")
            let europeCount = try await client
                .from("places")
                .select("*", head: true, count: .exact)
                .or(europeFilter)
                .execute()
                .count ?? 0
            
            print("📊 Europe total: \(europeCount)")
            
            // Americas count
            let americasFilter = americasCountries.map { "country.ilike.%\($0)%" }.joined(separator: ",")
            let americasCount = try await client
                .from("places")
                .select("*", head: true, count: .exact)
                .or(americasFilter)
                .execute()
                .count ?? 0
            
            print("📊 Americas total: \(americasCount)")
            
            // Asia count
            let asiaFilter = asiaCountries.map { "country.ilike.%\($0)%" }.joined(separator: ",")
            let asiaCount = try await client
                .from("places")
                .select("*", head: true, count: .exact)
                .or(asiaFilter)
                .execute()
                .count ?? 0
            
            print("📊 Asia total: \(asiaCount)")
            
            var stats = RegionalStats()
            stats.worldTotal = worldCount
            stats.europeTotal = europeCount
            stats.americasTotal = americasCount
            stats.asiaTotal = asiaCount
            
            regionalStats = stats
            
            print("📊 All stats updated!")
            
        } catch {
            print("❌ Error fetching regional stats: \(error)")
        }
    }
    
    /// Get visited count for a region
    func visitedInRegion(_ countries: [String]) -> Int {
        var count = 0
        for id in visitedIDs {
            if let place = places.first(where: { $0.id == id }),
               let country = place.country,
               countries.contains(where: { country.localizedCaseInsensitiveContains($0) }) {
                count += 1
            }
        }
        return count
    }
    
    // Tutte le categorie disponibili dai luoghi caricati
    var availableCategories: [String] {
        let allCategories = places.compactMap { $0.categoryName }
        return Array(Set(allCategories)).sorted()
    }
    
    // Filtra i luoghi per mostrare solo quelli con coordinate valide
    var validPlaces: [Place] {
        places.filter { $0.coordinate != nil && $0.hide_from_maps != "true" }
    }
    
    // Luoghi preferiti
    var favoritePlaces: [Place] {
        validPlaces.filter { favoriteIDs.contains($0.id) }
    }
    
    // Filtra i luoghi in base alla ricerca e alle categorie selezionate
    var filteredPlaces: [Place] {
        var filtered = validPlaces
        
        // Filtro per categorie se ce ne sono selezionate
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { place in
                guard let category = place.categoryName else { return false }
                return selectedCategories.contains(category)
            }
        }
        
        // Filtro per ricerca
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { place in
                // Cerca nel titolo
                if let title = place.title?.lowercased(), title.contains(searchLower) {
                    return true
                }
                
                // Cerca nel subtitle
                if let subtitle = place.subtitle?.lowercased(), subtitle.contains(searchLower) {
                    return true
                }
                
                // Cerca nella città
                if let city = place.city?.lowercased(), city.contains(searchLower) {
                    return true
                }
                
                // Cerca nel paese
                if let country = place.country?.lowercased(), country.contains(searchLower) {
                    return true
                }
                
                // Cerca nella descrizione (first 200 chars only for performance)
                if let description = place.description?.prefix(200).lowercased(), description.contains(searchLower) {
                    return true
                }
                
                return false
            }
        }
        
        return filtered
    }
    
    /// Apply advanced filters and sorting
    func applyFilters(sortOrder: SortOrder, maxDistance: Double?, showOnlyUnvisited: Bool) {
        self.currentSortOrder = sortOrder
        self.maxDistanceFilter = maxDistance
        self.showOnlyUnvisited = showOnlyUnvisited
        
        // Trigger UI update
        objectWillChange.send()
        
        // Update clustering with current region
        if let region = currentDisplayRegion {
            updateClusteredItems(for: region)
        }
    }
    
    /// Get places with all filters applied
    func getFilteredAndSortedPlaces(userLocation: CLLocationCoordinate2D?) -> [Place] {
        var result = filteredPlaces
        
        // Apply unvisited filter
        if showOnlyUnvisited {
            result = result.filter { !visitedIDs.contains($0.id) }
        }
        
        // Apply distance filter
        if let maxDist = maxDistanceFilter, let userLoc = userLocation {
            result = result.filter { place in
                guard let placeCoord = place.coordinate else { return false }
                let distance = self.calculateDistance(from: userLoc, to: placeCoord)
                return distance <= maxDist
            }
        }
        
        // Apply sorting
        switch currentSortOrder {
        case .distance:
            if let userLoc = userLocation {
                result.sort { place1, place2 in
                    let dist1 = place1.coordinate.map { calculateDistance(from: userLoc, to: $0) } ?? Double.infinity
                    let dist2 = place2.coordinate.map { calculateDistance(from: userLoc, to: $0) } ?? Double.infinity
                    return dist1 < dist2
                }
            }
        case .name:
            result.sort { ($0.title ?? "") < ($1.title ?? "") }
        case .recent:
            // Keep original order (assumed to be by ID/recent)
            result.sort { $0.id > $1.id }
        }
        
        return result
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // km
    }
    
    // MARK: - Preferiti
    
    func toggleFavorite(_ id: Int64) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
            userDefaults.removeFavorite(id)
            favoritePlacesFull.removeAll { $0.id == id }
        } else {
            favoriteIDs.insert(id)
            userDefaults.addFavorite(id)
            // Add the place to favoritePlacesFull if it exists in places
            if let place = places.first(where: { $0.id == id }) {
                favoritePlacesFull.append(place)
            }
        }
    }
    
    func isFavorite(_ id: Int64) -> Bool {
        favoriteIDs.contains(id)
    }
    
    // MARK: - Visitati
    
    func toggleVisited(_ id: Int64) {
        if visitedIDs.contains(id) {
            visitedIDs.remove(id)
            userDefaults.removeVisited(id)
        } else {
            visitedIDs.insert(id)
            userDefaults.addVisited(id)
        }
    }
    
    func isVisited(_ id: Int64) -> Bool {
        visitedIDs.contains(id)
    }
    
    // MARK: - Categorie
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        userDefaults.saveSelectedCategories(selectedCategories)
    }
    
    func clearCategoryFilters() {
        selectedCategories.removeAll()
        userDefaults.saveSelectedCategories(selectedCategories)
    }
    
    // MARK: - Data Loading
    
    /// Carica i luoghi nella regione visibile della mappa
    func fetchPlacesInRegion(_ region: MKCoordinateRegion) async {
        // Salva la regione corrente per il clustering
        currentDisplayRegion = region
        
        // Cancella il task precedente se esiste
        loadingTask?.cancel()
        
        // Evita di ricaricare se siamo ancora nella stessa regione (con margine ridotto)
        if let loadedRegion = loadedRegion {
            let latDiff = abs(loadedRegion.center.latitude - region.center.latitude)
            let lngDiff = abs(loadedRegion.center.longitude - region.center.longitude)
            let spanDiff = abs(loadedRegion.span.latitudeDelta - region.span.latitudeDelta)
            
            // Ricarica se ci siamo spostati anche poco o abbiamo zoomato
            let hasMovedSignificantly = latDiff > region.span.latitudeDelta * 0.2 || 
                                        lngDiff > region.span.longitudeDelta * 0.2
            let hasZoomedSignificantly = spanDiff > region.span.latitudeDelta * 0.3
            
            if !hasMovedSignificantly && !hasZoomedSignificantly {
                // Aggiorna comunque il clustering con la regione corrente
                updateClusteredItems(for: region)
                return // Ancora nella stessa area, usa la cache
            }
        }
        
        // Crea un nuovo task di caricamento
        loadingTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            // Calcola i bounds della regione con margine ridotto per seguire meglio la visuale
            let margin = 1.2 // Carica solo 20% in più per essere più preciso
            let latDelta = region.span.latitudeDelta * margin
            let lngDelta = region.span.longitudeDelta * margin
            
            let minLat = region.center.latitude - latDelta / 2
            let maxLat = region.center.latitude + latDelta / 2
            let minLng = region.center.longitude - lngDelta / 2
            let maxLng = region.center.longitude + lngDelta / 2
            
            do {
                var query = SupabaseManager.shared.client
                    .from("places")
                    .select()
                    .gte("coordinates_lat", value: minLat)
                    .lte("coordinates_lat", value: maxLat)
                    .gte("coordinates_lng", value: minLng)
                    .lte("coordinates_lng", value: maxLng)
                
                // Se c'è una ricerca attiva, filtra anche per testo
                if !searchText.isEmpty {
                    let searchStr = searchText.lowercased()
                    query = query.or("title.ilike.%\(searchStr)%,description.ilike.%\(searchStr)%,city.ilike.%\(searchStr)%")
                }
                
                let data: [Place] = try await query
                    .limit(1000) // Aumentato grazie al clustering
                    .execute()
                    .value
                
                // Controlla se il task è stato cancellato
                if Task.isCancelled { return }
                
                // SOSTITUISCI i luoghi invece di fare merge - mostra solo quelli nella regione visibile
                self.places = data
                self.loadedRegion = region
                print("✅ Loaded \(data.count) places in visible region")
                print("   Region: lat \(String(format: "%.2f", minLat))-\(String(format: "%.2f", maxLat)), lng \(String(format: "%.2f", minLng))-\(String(format: "%.2f", maxLng))")
                
                // Aggiorna il clustering subito dopo il caricamento
                self.updateClusteredItems(for: region)
                
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Loading error: \(error.localizedDescription)"
                    print("❌ Supabase error: \(error)")
                }
            }
            
            // Nascondi loading dopo un breve delay per evitare flickering
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondi minimo
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
    
    /// Carica tutti i luoghi dal database (da usare solo se necessario)
    func fetchAllPlaces(limit: Int = 1000) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .limit(limit)
                .execute()
                .value
            
            self.places = data
            print("✅ Loaded \(data.count) places from Supabase")
        } catch {
            self.errorMessage = "Loading error: \(error.localizedDescription)"
            print("❌ Supabase error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Carica i luoghi vicini a una coordinata specifica
    func fetchPlacesNearby(
        coordinate: CLLocationCoordinate2D,
        radiusInKm: Double = 50
    ) async {
        isLoading = true
        errorMessage = nil
        
        // Converti km in gradi approssimativamente (1 grado ≈ 111 km)
        let radiusInDegrees = radiusInKm / 111.0
        
        let minLat = coordinate.latitude - radiusInDegrees
        let maxLat = coordinate.latitude + radiusInDegrees
        let minLng = coordinate.longitude - radiusInDegrees
        let maxLng = coordinate.longitude + radiusInDegrees
        
        do {
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .gte("coordinates_lat", value: minLat)
                .lte("coordinates_lat", value: maxLat)
                .gte("coordinates_lng", value: minLng)
                .lte("coordinates_lng", value: maxLng)
                .execute()
                .value
            
            self.places = data
            print("✅ Trovati \(data.count) luoghi vicini")
        } catch {
            self.errorMessage = "Errore nella ricerca: \(error.localizedDescription)"
            print("❌ Errore ricerca vicini: \(error)")
        }
        
        isLoading = false
    }
    
    /// Calcola la distanza di un luogo dalla posizione corrente
    func distance(from userLocation: CLLocationCoordinate2D, to place: Place) -> Double? {
        guard let placeCoordinate = place.coordinate else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let placeCLLocation = CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude)
        
        return userCLLocation.distance(from: placeCLLocation) / 1000.0 // distanza in km
    }
    
    // MARK: - Fetch Favorites
    
    func fetchFavoritePlaces() async {
        guard !favoriteIDs.isEmpty else {
            favoritePlacesFull = []
            return
        }
        
        do {
            // Build OR filter for each ID: id.eq.1,id.eq.2,id.eq.3,...
            let orFilter = favoriteIDs.map { "id.eq.\($0)" }.joined(separator: ",")
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .or(orFilter)
                .execute()
                .value
            
            self.favoritePlacesFull = data
            print("✅ Fetched \(data.count) favorite places")
        } catch {
            print("❌ Error fetching favorites: \(error)")
        }
    }
    
    // MARK: - Global Search
    
    func performGlobalSearch() async {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let query = searchText.lowercased()
            let data: [Place] = try await SupabaseManager.shared.client
                .from("places")
                .select()
                .or("title.ilike.%\(query)%,description.ilike.%\(query)%,city.ilike.%\(query)%")
                .limit(50)
                .execute()
                .value
            
            if !Task.isCancelled {
                self.places = data
                self.calculateRegionForPlaces(data)
            }
            
            print("✅ Found \(data.count) places for query: \(query)")
        } catch {
            self.errorMessage = "Search error: \(error.localizedDescription)"
            print("❌ Search error: \(error)")
        }
        
        isLoading = false
    }
    
    
    private func calculateRegionForPlaces(_ places: [Place]) {
        guard !places.isEmpty else { return }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0
        
        for place in places {
            guard let coord = place.coordinate else { continue }
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }
        
        // If only one place, use a fixed span
        if places.count == 1 {
            let center = CLLocationCoordinate2D(latitude: minLat, longitude: minLng)
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            self.regionToRecenter = EquatableRegion(region: MKCoordinateRegion(center: center, span: span))
            return
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.05)
        )
        
        self.regionToRecenter = EquatableRegion(region: MKCoordinateRegion(center: center, span: span))
    }
    
    /// Navigate to a specific region (used by city search)
    func navigateToRegion(_ region: MKCoordinateRegion) {
        // Clear current places for fresh load
        loadedRegion = nil
        
        // Set the region to recenter the map
        self.regionToRecenter = EquatableRegion(region: region)
        
        // Fetch places in the new region
        Task {
            await fetchPlacesInRegion(region)
        }
    }
    
    // MARK: - Clustering
    
    func updateClusteredItems(for region: MKCoordinateRegion) {
        let places = filteredPlaces
        guard !places.isEmpty else {
            clusteredItems = []
            return
        }
        
        // Soglia di distanza per raggruppare (dipende dallo zoom)
        // Più alto è lo zoom (delta piccolo), più piccola è la soglia
        // Ridotto divisore: i pin si separano prima durante lo zoom
        let threshold = region.span.latitudeDelta / 30.0
        
        var items: [MapItem] = []
        var processedIndices = Set<Int>()
        
        for i in 0..<places.count {
            if processedIndices.contains(i) { continue }
            
            let placeA = places[i]
            guard let coordA = placeA.coordinate else { continue }
            
            var clusterPlaces: [Place] = [placeA]
            processedIndices.insert(i)
            
            // Cerca vicini
            for j in (i + 1)..<places.count {
                if processedIndices.contains(j) { continue }
                
                let placeB = places[j]
                guard let coordB = placeB.coordinate else { continue }
                
                let latDiff = abs(coordA.latitude - coordB.latitude)
                let lngDiff = abs(coordA.longitude - coordB.longitude)
                
                if latDiff < threshold && lngDiff < threshold {
                    clusterPlaces.append(placeB)
                    processedIndices.insert(j)
                }
            }
            
            if clusterPlaces.count > 1 {
                // Crea cluster
                let avgLat = clusterPlaces.reduce(0.0) { $0 + ($1.coordinate?.latitude ?? 0) } / Double(clusterPlaces.count)
                let avgLng = clusterPlaces.reduce(0.0) { $0 + ($1.coordinate?.longitude ?? 0) } / Double(clusterPlaces.count)
                let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
                
                items.append(.cluster(id: UUID().uuidString, coordinate: center, places: clusterPlaces))
            } else {
                items.append(.place(placeA))
            }
        }
        
        self.clusteredItems = items
    }
}
