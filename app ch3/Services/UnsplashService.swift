//
//  UnsplashService.swift
//  app ch3
//
//  Service to fetch high-quality photos from Unsplash (FREE - 50 req/hour)
//

import Foundation

struct UnsplashPhoto {
    let id: String
    let url: String           // Regular size
    let thumbURL: String      // Thumbnail
    let fullURL: String       // Full size
    let photographer: String
    let photographerURL: String
}

class UnsplashService {
    
    // Free Unsplash API - register at unsplash.com/developers
    // Demo key - replace with your own for production
    private let accessKey = "YOUR_UNSPLASH_ACCESS_KEY"
    private let baseURL = "https://api.unsplash.com"
    
    /// Search for photos of a place
    func searchPhotos(query: String, count: Int = 5) async -> [UnsplashPhoto] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/photos?query=\(encodedQuery)&per_page=\(count)&orientation=landscape") else {
            print("❌ UnsplashService: Invalid URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.addValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return []
            }
            
            // Check rate limit
            if httpResponse.statusCode == 403 {
                print("⚠️ UnsplashService: Rate limit reached")
                return []
            }
            
            guard httpResponse.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                print("❌ UnsplashService: No results or invalid response")
                return []
            }
            
            var photos: [UnsplashPhoto] = []
            
            for result in results {
                guard let id = result["id"] as? String,
                      let urls = result["urls"] as? [String: String],
                      let user = result["user"] as? [String: Any] else {
                    continue
                }
                
                let photo = UnsplashPhoto(
                    id: id,
                    url: urls["regular"] ?? "",
                    thumbURL: urls["thumb"] ?? "",
                    fullURL: urls["full"] ?? "",
                    photographer: user["name"] as? String ?? "Unknown",
                    photographerURL: (user["links"] as? [String: String])?["html"] ?? ""
                )
                photos.append(photo)
            }
            
            print("✅ UnsplashService: Found \(photos.count) photos for '\(query)'")
            return photos
            
        } catch {
            print("❌ UnsplashService: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get a random photo for a place (uses less API quota)
    func getRandomPhoto(query: String) async -> UnsplashPhoto? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/photos/random?query=\(encodedQuery)&orientation=landscape") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = result["id"] as? String,
                  let urls = result["urls"] as? [String: String],
                  let user = result["user"] as? [String: Any] else {
                return nil
            }
            
            return UnsplashPhoto(
                id: id,
                url: urls["regular"] ?? "",
                thumbURL: urls["thumb"] ?? "",
                fullURL: urls["full"] ?? "",
                photographer: user["name"] as? String ?? "Unknown",
                photographerURL: (user["links"] as? [String: String])?["html"] ?? ""
            )
            
        } catch {
            return nil
        }
    }
}

// MARK: - Fallback with sample photos (no API key needed)

extension UnsplashService {
    
    /// Get sample placeholder photos (no API needed)
    static func getSamplePhotos(for category: String) -> [String] {
        let sampleURLs: [String: [String]] = [
            "church": [
                "https://images.unsplash.com/photo-1548625361-1cdab53e93f9",
                "https://images.unsplash.com/photo-1509128841709-6c13b25058a3"
            ],
            "castle": [
                "https://images.unsplash.com/photo-1533154683836-84ea7a0bc310",
                "https://images.unsplash.com/photo-1551918120-9739cb430c6d"
            ],
            "museum": [
                "https://images.unsplash.com/photo-1554907984-15263bfd63bd",
                "https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7"
            ],
            "default": [
                "https://images.unsplash.com/photo-1499856871958-5b9627545d1a",
                "https://images.unsplash.com/photo-1502602898657-3e91760cbb34"
            ]
        ]
        
        let key = sampleURLs.keys.first { category.lowercased().contains($0) } ?? "default"
        return sampleURLs[key] ?? sampleURLs["default"]!
    }
}
