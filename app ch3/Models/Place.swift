//
//  Place.swift
//  app ch3
//
//  Modello che rappresenta un luogo segreto dalla tabella Supabase
//

import Foundation
import CoreLocation

struct Place: Decodable, Identifiable {
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
        title ?? "Luogo segreto"
    }
    
    // Località completa (città + paese)
    var fullLocation: String? {
        switch (city, country) {
        case (let city?, let country?):
            return "\(city), \(country)"
        case (let city?, nil):
            return city
        case (nil, let country?):
            return country
        default:
            return location
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
    /// Remove HTML tags from string
    func stripHTML() -> String {
        // Remove HTML tags
        var result = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Clean up extra whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MapItem: Identifiable {
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
