//
//  Place.swift
//  app ch3
//
//  Modello che rappresenta un luogo segreto dalla tabella Supabase
//

import Foundation
import CoreLocation

struct Place: Decodable, Identifiable, Sendable {
    let id: Int64
    let title: String?
    let subtitle: String?
    let city: String?
    let country: String?
    let location: String?
    let url: String?
    let hide_from_maps: String?
    let physical_status: String?
    let thumbnail_url: String?
    let thumbnail_url_3x2: String?
    let coordinates_lat: Double?
    let coordinates_lng: Double?
    let description: String?
    let directions: String?
    let tags_title: String?
    let tags_link: String?
    let image_cover: String?
    let images: String?
    
    // Category name formatted for display
    var categoryName: String? {
        guard let link = tags_link else { return nil }
        // Remove "/categories/" prefix and convert to readable format
        let cleanName = link.replacingOccurrences(of: "/categories/", with: "")
        // Replace hyphens with spaces and capitalize words
        return cleanName
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
            .stripHTML()
    }
    
    // Computed property per ottenere le coordinate come CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = coordinates_lat, let lng = coordinates_lng else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    // Nome del luogo per display
    var displayName: String {
        (title ?? "Luogo segreto").stripHTML()
    }
    
    // Località completa (città + paese)
    var fullLocation: String? {
        switch (city, country) {
        case (let city?, let country?):
            return "\(city), \(country)".stripHTML()
        case (let city?, nil):
            return city.stripHTML()
        case (nil, let country?):
            return country.stripHTML()
        case (nil, nil):
            return location?.stripHTML()
        }
    }
    
    // Description cleaned from HTML tags
    var cleanDescription: String? {
        description?.stripHTML()
    }
    
    // Directions cleaned from HTML tags
    var cleanDirections: String? {
        directions?.stripHTML()
    }
}

// MARK: - String Extension for HTML Stripping

extension String {
    /// Try to fix common encoding errors (Mojibake) and apply manual patches
    /// Converts Windows-1252/Latin-1 interpreted UTF-8 back to UTF-8
    func fixEncoding() -> String {
        // 0. Manual Patch List for known DB corruptions (since DB is read-only/broken)
        let manualFixes: [String: String] = [
            "Gro?njan": "Grožnjan",
            "V?rsar": "Vrsar", // Common Istrian town issue
            "Pore?": "Poreč",
            "Rovin?": "Rovinj",
            "Motov?n": "Motovun"
        ]
        
        // Fast path: check if string contains any of the known broken parts
        for (broken, fixed) in manualFixes {
            if self.contains(broken) {
                return self.replacingOccurrences(of: broken, with: fixed)
            }
        }
    
        // 1. If it contains common Mojibake patterns, try to fix
        // Patterns: Ã¨ (è), Ã© (é), â€™ (’), Ã  (à)
        let mojibakeIndicators = ["Ã¨", "Ã©", "â€™", "Ã ", "Ã¹", "Ã¬", "Ã²"]
        
        let needsFix = mojibakeIndicators.contains { self.contains($0) }
        
        if needsFix {
            // Try enabling lossy conversion to catch mixed content
            if let lat1Data = self.data(using: .isoLatin1, allowLossyConversion: true) {
                if let fixed = String(data: lat1Data, encoding: .utf8) {
                    return fixed
                }
            }
        }
        
        return self
    }

    /// Remove HTML tags and decode entities using Regex (Crash-safe)
    func stripHTML() -> String {
        // 1. Fix encoding first
        var text = self.fixEncoding()
        
        // 2. Remove HTML tags using Regex
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: text.utf16.count)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        // 3. Basic Entity Decoding (Common ones)
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&ndash;": "-",
            "&mdash;": "—"
        ]
        
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MapItem: Identifiable, Sendable {
    case place(Place)
    case cluster(id: String, coordinate: CLLocationCoordinate2D, places: [Place])
    
    var id: String {
        switch self {
        case .place(let p): return String(p.id)
        case .cluster(let id, _, _): return "cluster-\(id)"
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .place(let p): return p.coordinate ?? CLLocationCoordinate2D()
        case .cluster(_, let c, _): return c
        }
    }
}
