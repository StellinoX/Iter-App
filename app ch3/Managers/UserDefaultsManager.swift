//
//  UserDefaultsManager.swift
//  app ch3
//
//  Gestisce la persistenza di preferiti, visitati e filtri categorie
//

import Foundation

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let favoritesKey = "favoritePlaceIDs"
    private let visitedKey = "visitedPlaceIDs"
    private let selectedCategoriesKey = "selectedCategories"
    private let notesKey = "placeNotes"
    private let itinerariesKey = "itineraries"
    private let maxDistanceKey = "maxDistanceFilter"
    private let sortOrderKey = "sortOrder"
    private let showOnlyUnvisitedKey = "showOnlyUnvisited"
    private let proximityNotificationsKey = "proximityNotificationsEnabled"
    private let darkMapModeKey = "darkMapMode"
    
    private init() {}
    
    // MARK: - Preferiti
    
    func getFavorites() -> Set<Int64> {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let ids = try? JSONDecoder().decode(Set<Int64>.self, from: data) {
            return ids
        }
        return []
    }
    
    func saveFavorites(_ ids: Set<Int64>) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
    
    func addFavorite(_ id: Int64) {
        var favorites = getFavorites()
        favorites.insert(id)
        saveFavorites(favorites)
    }
    
    func removeFavorite(_ id: Int64) {
        var favorites = getFavorites()
        favorites.remove(id)
        saveFavorites(favorites)
    }
    
    func isFavorite(_ id: Int64) -> Bool {
        getFavorites().contains(id)
    }
    
    // MARK: - Visitati
    
    func getVisited() -> Set<Int64> {
        if let data = UserDefaults.standard.data(forKey: visitedKey),
           let ids = try? JSONDecoder().decode(Set<Int64>.self, from: data) {
            return ids
        }
        return []
    }
    
    func saveVisited(_ ids: Set<Int64>) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: visitedKey)
        }
    }
    
    func addVisited(_ id: Int64) {
        var visited = getVisited()
        visited.insert(id)
        saveVisited(visited)
    }
    
    func removeVisited(_ id: Int64) {
        var visited = getVisited()
        visited.remove(id)
        saveVisited(visited)
    }
    
    func isVisited(_ id: Int64) -> Bool {
        getVisited().contains(id)
    }
    
    func toggleVisited(_ id: Int64) {
        if isVisited(id) {
            removeVisited(id)
        } else {
            addVisited(id)
        }
    }
    
    // MARK: - Categorie selezionate
    
    func getSelectedCategories() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: selectedCategoriesKey),
           let categories = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return categories
        }
        return []
    }
    
    func saveSelectedCategories(_ categories: Set<String>) {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: selectedCategoriesKey)
        }
    }
    
    // MARK: - Notes
    
    func getAllNotes() -> [Int64: PlaceNote] {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let notes = try? JSONDecoder().decode([Int64: PlaceNote].self, from: data) {
            return notes
        }
        return [:]
    }
    
    func getNote(for placeId: Int64) -> PlaceNote? {
        getAllNotes()[placeId]
    }
    
    func saveNote(_ note: PlaceNote) {
        var notes = getAllNotes()
        notes[note.placeId] = note
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }
    
    func deleteNote(for placeId: Int64) {
        var notes = getAllNotes()
        notes.removeValue(forKey: placeId)
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }
    
    // MARK: - Itineraries
    
    func getAllItineraries() -> [Itinerary] {
        if let data = UserDefaults.standard.data(forKey: itinerariesKey),
           let itineraries = try? JSONDecoder().decode([Itinerary].self, from: data) {
            return itineraries
        }
        return []
    }
    
    func saveItineraries(_ itineraries: [Itinerary]) {
        if let data = try? JSONEncoder().encode(itineraries) {
            UserDefaults.standard.set(data, forKey: itinerariesKey)
        }
    }
    
    func addItinerary(_ itinerary: Itinerary) {
        var all = getAllItineraries()
        all.append(itinerary)
        saveItineraries(all)
    }
    
    func updateItinerary(_ itinerary: Itinerary) {
        var all = getAllItineraries()
        if let index = all.firstIndex(where: { $0.id == itinerary.id }) {
            all[index] = itinerary
            saveItineraries(all)
        }
    }
    
    func deleteItinerary(_ id: UUID) {
        var all = getAllItineraries()
        all.removeAll { $0.id == id }
        saveItineraries(all)
    }
    
    // MARK: - Saved Trips
    
    private let savedTripsKey = "savedTrips"
    
    func getSavedTrips() -> [Trip] {
        if let data = UserDefaults.standard.data(forKey: savedTripsKey),
           let trips = try? JSONDecoder().decode([Trip].self, from: data) {
            // Sort by startDate, upcoming first
            return trips.sorted { $0.startDate < $1.startDate }
        }
        return []
    }
    
    func saveSavedTrips(_ trips: [Trip]) {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: savedTripsKey)
        }
    }
    
    func saveTrip(_ trip: Trip) {
        var all = getSavedTrips()
        // Remove existing with same ID
        all.removeAll { $0.id == trip.id }
        all.append(trip)
        saveSavedTrips(all)
    }
    
    func deleteTrip(_ id: UUID) {
        var all = getSavedTrips()
        all.removeAll { $0.id == id }
        saveSavedTrips(all)
    }
    
    // MARK: - Filter Settings
    
    var maxDistanceFilter: Double? {
        get {
            let value = UserDefaults.standard.double(forKey: maxDistanceKey)
            return value > 0 ? value : nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: maxDistanceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: maxDistanceKey)
            }
        }
    }
    
    var sortOrder: SortOrder {
        get {
            let rawValue = UserDefaults.standard.string(forKey: sortOrderKey) ?? "distance"
            return SortOrder(rawValue: rawValue) ?? .distance
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sortOrderKey)
        }
    }
    
    var showOnlyUnvisited: Bool {
        get { UserDefaults.standard.bool(forKey: showOnlyUnvisitedKey) }
        set { UserDefaults.standard.set(newValue, forKey: showOnlyUnvisitedKey) }
    }
    
    // MARK: - App Settings
    
    var proximityNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: proximityNotificationsKey) }
        set { UserDefaults.standard.set(newValue, forKey: proximityNotificationsKey) }
    }
    
    var darkMapMode: Bool {
        get { UserDefaults.standard.bool(forKey: darkMapModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: darkMapModeKey) }
    }
}

// MARK: - Sort Order Enum

enum SortOrder: String, CaseIterable {
    case distance = "distance"
    case name = "name"
    case recent = "recent"
    
    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .name: return "Name"
        case .recent: return "Recently Added"
        }
    }
    
    var icon: String {
        switch self {
        case .distance: return "location"
        case .name: return "textformat.abc"
        case .recent: return "clock"
        }
    }
}
