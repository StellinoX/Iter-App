//
//  AIService.swift
//  app ch3
//
//  Unified AI service with Apple Intelligence (iOS 26+) and Gemini fallback
//

import Foundation
import Combine

/// Unified AI service that uses Apple Intelligence when available, falls back to Gemini
@MainActor
class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private let geminiService = GeminiService()
    
    /// Check if Apple Intelligence is available on this device
    var isAppleIntelligenceAvailable: Bool {
        // Apple Foundation Models requires iOS 26+ (announced as iOS 18.4 feature)
        // Currently not released, so we check for future availability
        if #available(iOS 26.0, *) {
            // In the future, check:
            // return LanguageModelSession.isAvailable
            return false // Will be enabled when iOS 26 releases
        }
        return false
    }
    
    /// Generate itinerary using best available AI
    func generateItinerary(city: String, days: Int, places: [Place], hotelAddress: String = "", pace: String = "Balanced", vibe: String = "Casual") async -> [TripDay]? {
        isLoading = true
        error = nil
        
        // For now, always use Gemini as Apple Intelligence is not yet available
        // When iOS 26 releases, this will be updated to use Apple Foundation Models first
        
        if isAppleIntelligenceAvailable {
            print("🍎 AIService: Using Apple Intelligence")
            // TODO: Implement Apple Foundation Models when available
            // let result = await generateWithAppleIntelligence(...)
            // if result != nil { return result }
        }
        
        print("🤖 AIService: Using Gemini fallback")
        let result = await geminiService.generateItinerary(
            city: city,
            days: days,
            places: places,
            hotelAddress: hotelAddress,
            pace: pace,
            vibe: vibe
        )
        
        isLoading = false
        return result
    }
    
    /// Suggest next places using best available AI
    func suggestNextPlaces(
        availablePlaces: [Place],
        selectedPlaces: [Place],
        hotelAddress: String,
        count: Int = 4
    ) async -> [Int64] {
        
        if isAppleIntelligenceAvailable {
            print("🍎 AIService: Using Apple Intelligence for suggestions")
            // TODO: Implement Apple Foundation Models when available
        }
        
        print("🤖 AIService: Using Gemini for suggestions")
        return await geminiService.suggestNextPlaces(
            availablePlaces: availablePlaces,
            selectedPlaces: selectedPlaces,
            hotelAddress: hotelAddress,
            count: count
        )
    }
    
    /// Enhance place description using best available AI
    func enhanceDescription(placeName: String, originalDescription: String?, wikipediaInfo: String?, city: String?) async -> String? {
        
        if isAppleIntelligenceAvailable {
            print("🍎 AIService: Using Apple Intelligence for description")
            // TODO: Implement Apple Foundation Models when available
        }
        
        print("🤖 AIService: Using Gemini for description")
        return await geminiService.enhanceDescription(
            placeName: placeName,
            originalDescription: originalDescription,
            wikipediaInfo: wikipediaInfo,
            city: city
        )
    }
}

// MARK: - Apple Intelligence Implementation (iOS 26+)
// This section will be enabled when Apple Foundation Models becomes available

/*
@available(iOS 26.0, *)
extension AIService {
    
    /// Generate itinerary using Apple Foundation Models
    private func generateWithAppleIntelligence(city: String, days: Int, places: [Place], hotelAddress: String) async -> [TripDay]? {
        guard LanguageModelSession.isAvailable else {
            return nil
        }
        
        do {
            let session = LanguageModelSession()
            
            let placesList = places.prefix(20).map { place in
                "\(place.displayName) - \(place.cleanDescription ?? "")"
            }.joined(separator: "\n")
            
            let prompt = """
            Create a \(days)-day travel itinerary for \(city).
            Available places: \(placesList)
            Hotel: \(hotelAddress.isEmpty ? "City Center" : hotelAddress)
            
            For each day, suggest 4 places with times and walking directions.
            """
            
            let response = try await session.respond(to: prompt)
            
            // Parse response and create TripDay objects
            // This will need to be implemented based on the actual API response format
            return nil // Placeholder
            
        } catch {
            print("❌ Apple Intelligence error: \(error)")
            return nil
        }
    }
}
*/
