//
//  WikipediaService.swift
//  app ch3
//
//  Service to fetch Wikipedia info and images for places (FREE!)
//

import Foundation

struct WikipediaInfo {
    let title: String
    let extract: String        // Short description
    let fullExtract: String    // Full description
    let imageURL: String?
    let pageURL: String
}

class WikipediaService {
    
    private let baseURL = "https://en.wikipedia.org/api/rest_v1"
    
    /// Search Wikipedia for a place and get summary + image
    func getPlaceInfo(placeName: String, city: String? = nil) async -> WikipediaInfo? {
        // Create search query
        let searchQuery = city != nil ? "\(placeName) \(city!)" : placeName
        
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/page/summary/\(encodedQuery)") else {
            print("❌ WikipediaService: Invalid URL")
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.addValue("HiddenPlacesApp/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Try without city name
                if city != nil {
                    return await getPlaceInfo(placeName: placeName, city: nil)
                }
                print("❌ WikipediaService: Not found")
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let title = json["title"] as? String ?? placeName
            let extract = json["extract"] as? String ?? ""
            let description = json["description"] as? String ?? ""
            
            // Get image URL from thumbnail
            var imageURL: String? = nil
            if let originalImage = json["originalimage"] as? [String: Any] {
                imageURL = originalImage["source"] as? String
            } else if let thumbnail = json["thumbnail"] as? [String: Any] {
                imageURL = thumbnail["source"] as? String
            }
            
            // Get page URL
            let contentUrls = json["content_urls"] as? [String: Any]
            let desktop = contentUrls?["desktop"] as? [String: Any]
            let pageURL = desktop?["page"] as? String ?? "https://en.wikipedia.org/wiki/\(encodedQuery)"
            
            print("✅ WikipediaService: Found info for \(title)")
            
            return WikipediaInfo(
                title: title,
                extract: description.isEmpty ? String(extract.prefix(200)) : description,
                fullExtract: extract,
                imageURL: imageURL,
                pageURL: pageURL
            )
            
        } catch {
            print("❌ WikipediaService: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Search for multiple images related to a place
    func getImages(for placeName: String, limit: Int = 5) async -> [String] {
        guard let encodedQuery = placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&titles=\(encodedQuery)&prop=images&format=json&imlimit=\(limit)") else {
            return []
        }
        
        do {
            var request = URLRequest(url: url)
            request.addValue("HiddenPlacesApp/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let pages = query["pages"] as? [String: Any] else {
                return []
            }
            
            var imageNames: [String] = []
            for (_, page) in pages {
                if let pageDict = page as? [String: Any],
                   let images = pageDict["images"] as? [[String: Any]] {
                    for image in images {
                        if let title = image["title"] as? String,
                           !title.contains(".svg"),
                           !title.contains("Commons-logo"),
                           !title.contains("Icon") {
                            imageNames.append(title)
                        }
                    }
                }
            }
            
            return imageNames
            
        } catch {
            return []
        }
    }
}
