//
//  GeminiService.swift
//  app ch3
//
//  AI service for generating smart itineraries using Gemini API
//

import Foundation
import Combine

@MainActor
class GeminiService: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    // Gemini API key
    private let apiKey = "AIzaSyCV59q-dDxnw-150KaJpTI2pPIlSUMiVAM"
    // Updated to use gemini-1.5-flash (more reliable)
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    /// Generate itinerary using places from the database
    func generateItinerary(city: String, days: Int, places: [Place], hotelAddress: String = "") async -> [TripDay]? {
        isLoading = true
        error = nil
        
        print("🤖 GeminiService: Starting itinerary generation for \(city), \(days) days, \(places.count) places")
        if !hotelAddress.isEmpty {
            print("🤖 GeminiService: Hotel: \(hotelAddress)")
        }
        
        // If no places provided, return fallback
        guard !places.isEmpty else {
            print("🤖 GeminiService: No places provided, using fallback")
            isLoading = false
            return generateFallbackItinerary(days: days, places: places)
        }
        
        // Create list of places with coordinates for distance calculations
        let placesList = places.prefix(20).enumerated().map { index, place in
            let lat = place.coordinates_lat ?? 0
            let lng = place.coordinates_lng ?? 0
            return "\(index + 1). \(place.displayName) [Lat: \(lat), Lng: \(lng)] - \(place.description?.prefix(80) ?? "Hidden gem")"
        }.joined(separator: "\n")
        
        let hotelInfo = hotelAddress.isEmpty ? "" : "\nHotel/Starting point: \(hotelAddress). Start each day from here and return in the evening."
        
        let prompt = """
        Sei un esperto di viaggi. Crea un itinerario di \(days) giorni per \(city).
        \(hotelInfo)
        
        LUOGHI DISPONIBILI (con coordinate per calcolare le distanze):
        \(placesList)
        
        ISTRUZIONI:
        1. Organizza i luoghi per vicinanza geografica (usa le coordinate)
        2. Calcola tempi di percorrenza realistici tra i luoghi
        3. Suggerisci mezzi pubblici reali (metro, bus, tram) quando possibile
        4. Per ogni spostamento indica: modo, durata, e dettagli (es. "Metro A direzione Battistini")
        
        Rispondi SOLO in JSON valido:
        {"days":[{"day":1,"activities":[{"placeIndex":1,"startTime":"09:00","duration":"2h","transportMode":"metro","transportDuration":"15 min","transportDetails":"Metro A da Termini a Spagna"}]}]}
        """
        
        // Make API request
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            print("🤖 GeminiService: Invalid URL")
            error = "Invalid URL"
            isLoading = false
            return generateFallbackItinerary(days: days, places: places)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("🤖 GeminiService: Sending request to Gemini...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🤖 GeminiService: Invalid response type")
                error = "Invalid response"
                isLoading = false
                return generateFallbackItinerary(days: days, places: places)
            }
            
            print("🤖 GeminiService: Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorText = String(data: data, encoding: .utf8) {
                    print("🤖 GeminiService: Error response: \(errorText)")
                }
                error = "API error: \(httpResponse.statusCode)"
                isLoading = false
                return generateFallbackItinerary(days: days, places: places)
            }
            
            // Parse response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                print("🤖 GeminiService: Got AI response: \(text.prefix(200))...")
                isLoading = false
                return parseAIResponse(text, days: days, places: Array(places.prefix(20)))
            } else {
                print("🤖 GeminiService: Failed to parse response structure")
                if let responseText = String(data: data, encoding: .utf8) {
                    print("🤖 GeminiService: Raw response: \(responseText.prefix(500))")
                }
            }
        } catch {
            print("🤖 GeminiService: Request error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
        return generateFallbackItinerary(days: days, places: places)
    }
    
    private func parseAIResponse(_ response: String, days: Int, places: [Place]) -> [TripDay]? {
        // Extract JSON from response (sometimes wrapped in markdown code blocks)
        var jsonString = response
        if let start = response.range(of: "{"), let end = response.range(of: "}", options: .backwards) {
            jsonString = String(response[start.lowerBound...end.upperBound])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daysArray = json["days"] as? [[String: Any]] else {
            return generateFallbackItinerary(days: days, places: places)
        }
        
        var tripDays: [TripDay] = []
        
        for (dayIndex, dayData) in daysArray.enumerated() {
            guard let activities = dayData["activities"] as? [[String: Any]] else { continue }
            
            let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: Date()) ?? Date()
            var tripDay = TripDay(dayNumber: dayIndex + 1, date: date)
            
            for activityData in activities {
                guard let placeIndex = activityData["placeIndex"] as? Int,
                      placeIndex > 0 && placeIndex <= places.count else { continue }
                
                let place = places[placeIndex - 1]
                var activity = TripActivity(
                    placeName: place.displayName,
                    startTime: activityData["startTime"] as? String ?? "09:00",
                    duration: activityData["duration"] as? String ?? "1h"
                )
                activity.placeId = place.id
                
                if let mode = activityData["transportMode"] as? String {
                    activity.transportMode = TransportMode(rawValue: mode)
                }
                activity.transportDuration = activityData["transportDuration"] as? String
                activity.transportDetails = activityData["transportDetails"] as? String
                activity.notes = place.description
                
                tripDay.activities.append(activity)
            }
            
            tripDays.append(tripDay)
        }
        
        return tripDays.isEmpty ? generateFallbackItinerary(days: days, places: places) : tripDays
    }
    
    private func generateFallbackItinerary(days: Int, places: [Place]) -> [TripDay] {
        var tripDays: [TripDay] = []
        let activitiesPerDay = 4
        
        for dayIndex in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: Date()) ?? Date()
            var tripDay = TripDay(dayNumber: dayIndex + 1, date: date)
            
            let times = ["09:00", "12:00", "15:00", "18:00"]
            let durations = ["2h", "1.5h", "2.5h", "2h"]
            
            for activityIndex in 0..<activitiesPerDay {
                let placeIndex = (dayIndex * activitiesPerDay + activityIndex) % max(1, places.count)
                
                if placeIndex < places.count {
                    let place = places[placeIndex]
                    var activity = TripActivity(
                        placeName: place.displayName,
                        startTime: times[activityIndex],
                        duration: durations[activityIndex]
                    )
                    activity.placeId = place.id
                    activity.transportMode = .walking
                    activity.transportDuration = "10 min"
                    activity.notes = place.description
                    tripDay.activities.append(activity)
                } else {
                    let activity = TripActivity(
                        placeName: "Esplorazione libera",
                        startTime: times[activityIndex],
                        duration: durations[activityIndex]
                    )
                    tripDay.activities.append(activity)
                }
            }
            
            tripDays.append(tripDay)
        }
        
        return tripDays
    }
    
    // MARK: - Description Enhancement
    
    /// Enhance a place description using Gemini AI
    func enhanceDescription(placeName: String, originalDescription: String?, wikipediaInfo: String?, city: String?) async -> String? {
        
        let context = """
        Nome luogo: \(placeName)
        Città: \(city ?? "non specificata")
        Descrizione originale: \(originalDescription ?? "nessuna")
        Info Wikipedia: \(wikipediaInfo ?? "nessuna")
        """
        
        let prompt = """
        Sei una guida turistica esperta. Riscrivi la descrizione di questo luogo in modo accattivante e informativo.

        \(context)

        Scrivi una descrizione di 3-4 frasi che includa:
        1. Cosa rende speciale questo luogo
        2. Un fatto storico o curiosità interessante  
        3. Un consiglio pratico per visitarlo

        Rispondi SOLO con la descrizione, senza intestazioni o formattazione.
        """
        
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            return nil
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 300
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                return nil
            }
            
            print("✨ GeminiService: Enhanced description for \(placeName)")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("❌ GeminiService: Enhancement error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - AI Place Suggestions
    
    /// Suggest next places for the itinerary based on selection
    func suggestNextPlaces(
        availablePlaces: [Place],
        selectedPlaces: [Place],
        hotelAddress: String,
        count: Int = 4
    ) async -> [Int64] {
        
        // Build context about available places
        let availableList = availablePlaces.prefix(50).map { place -> String in
            let coords = place.coordinate != nil ? "[Lat:\(place.coordinates_lat!), Lng:\(place.coordinates_lng!)]" : ""
            let desc = place.cleanDescription?.prefix(100) ?? ""
            return "ID:\(place.id) - \(place.displayName) \(coords) - \(desc)"
        }.joined(separator: "\n")
        
        // Build context about already selected places
        let selectedList = selectedPlaces.map { $0.displayName }.joined(separator: ", ")
        
        let prompt = """
        Sei un esperto di viaggi. Scegli i \(count) luoghi MIGLIORI per un itinerario turistico.

        PUNTO DI PARTENZA (Hotel/Airbnb): \(hotelAddress.isEmpty ? "Centro città" : hotelAddress)
        
        LUOGHI GIÀ SELEZIONATI: \(selectedList.isEmpty ? "Nessuno" : selectedList)
        
        LUOGHI DISPONIBILI:
        \(availableList)
        
        CRITERI DI SCELTA:
        1. Vicinanza geografica tra i luoghi (usa le coordinate)
        2. Varietà di categorie (non tutti musei, non tutte chiese)
        3. Complementarietà con i luoghi già selezionati
        4. Importanza/interesse turistico
        
        Rispondi SOLO con gli ID dei \(count) luoghi scelti, separati da virgola.
        Esempio: 123,456,789,101
        """
        
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            return []
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.5,
                "maxOutputTokens": 100
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ GeminiService: Suggestion failed")
                return []
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                return []
            }
            
            // Parse IDs from response
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let ids = cleanText.components(separatedBy: ",")
                .compactMap { Int64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            
            print("🎯 GeminiService: Suggested places: \(ids)")
            return ids
            
        } catch {
            print("❌ GeminiService: Suggestion error: \(error.localizedDescription)")
            return []
        }
    }
}
