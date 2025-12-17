//
//  SmartSanitizer.swift
//  app ch3
//
//  Created by Assistant.
//

import Foundation
import CoreLocation
import MapKit

/// Service responsible for repairing corrupted text (e.g., 'Gro?njan' -> 'Grožnjan')
/// Uses a combination of encoding fixes, manual patches, and Geocoding context.
final class SmartSanitizer {
    static let shared = SmartSanitizer()
    
    // Cache for reverse geocoded cities to avoid rate limits
    // Key: "lat,long" (rounded 3 decimals), Value: City Name
    private var cityCache: [String: String] = [:]
    
    private init() {}
    
    /// Main entry point to sanitize a string
    func sanitize(_ text: String, coordinate: CLLocationCoordinate2D? = nil) async -> String {
        // 1. Basic encoding fix (Mojibake reversal)
        var clean = text.fixEncoding()
        
        // If no suspicious '?' characters, we are done
        // Note: '?' is ASCII 63. Sometimes replacement char is 0xFFFD ()
        if !clean.contains("?") && !clean.contains("") {
            return clean
        }
        
        // 2. Try Context-based repair (Geocoding) for Place Names / Cities
        if let coord = coordinate, (clean.contains("?") || clean.contains("")) {
            if let correctCity = await getCityName(for: coord) {
                clean = smartReplace(original: clean, correctWord: correctCity)
            }
        }
        
        // 3. Fallback: Common dictionary for non-geo words
        // Use a small efficient list of very common broken words
        let commonFixes = [
            "Caf?": "Café",
            "caf?": "café",
            "Fa?ade": "Façade",
            "fa?ade": "façade",
            "Entr?e": "Entrée",
            "Jalape?o": "Jalapeño",
            "Pi?a": "Piña"
        ]
        
        for (broken, fixed) in commonFixes {
            clean = clean.replacingOccurrences(of: broken, with: fixed)
        }
        
        return clean
    }
    
    // MARK: - Geocoding Logic (using MKLocalSearch instead of deprecated CLGeocoder)
    
    private func getCityName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let key = "\(String(format: "%.3f", coordinate.latitude)),\(String(format: "%.3f", coordinate.longitude))"
        
        // Check cache
        if let cached = cityCache[key] {
            return cached
        }
        
        // Perform Lookup using MKLocalSearch (replaces deprecated CLGeocoder)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "city"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            // Use modern addressRepresentations API (iOS 26+) instead of deprecated placemark
            if let mapItem = response.mapItems.first,
               let city = mapItem.addressRepresentations?.cityName {
                cityCache[key] = city
                return city
            }
        } catch {
            print("⚠️ SmartSanitizer: MKLocalSearch failed for \(key): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Replaces a broken word in 'original' with 'correctWord' IF they look similar
    /// e.g. original: "Gro?njan Town", correct: "Grožnjan" -> "Grožnjan Town"
    private func smartReplace(original: String, correctWord: String) -> String {
        var text = original
        
        // Heuristic 1: If the correct word is contained but with wildcards
        // We create a Regex from the broken text parts
        // But simpler: Iterate words in original, if a word matches length and mostly chars of correctWord, replace it
        
        let words = text.components(separatedBy: .whitespaces)
        for i in 0..<words.count {
            let word = words[i]
            if word.contains("?") || word.contains("") {
                if isFuzzyMatch(broken: word, correct: correctWord) {
                    text = text.replacingOccurrences(of: word, with: correctWord)
                }
            }
        }
        
        // Heuristic 2: If the corrupted text IS the corrupted name entirely
        if isFuzzyMatch(broken: text, correct: correctWord) {
             return correctWord
        }
        
        return text
    }
    
    /// Returns true if 'broken' could be 'correct' with '?' acting as wildcard
    private func isFuzzyMatch(broken: String, correct: String) -> Bool {
        // Simple length check (allow ±1 diff for weird unicode expansion)
        if abs(broken.count - correct.count) > 1 { return false }
        
        // Create regex pattern from broken: replace ? with .
        let patternString = "^" + NSRegularExpression.escapedPattern(for: broken)
            .replacingOccurrences(of: "\\?", with: ".")
            .replacingOccurrences(of: "", with: ".") + "$"
        
        do {
            let regex = try NSRegularExpression(pattern: patternString, options: .caseInsensitive)
            let range = NSRange(location: 0, length: correct.utf16.count)
            return regex.firstMatch(in: correct, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}
