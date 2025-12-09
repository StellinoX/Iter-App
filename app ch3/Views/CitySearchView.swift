//
//  CitySearchView.swift
//  app ch3
//
//  Search for cities with autocomplete using MapKit
//

import SwiftUI
import MapKit
import Combine

@MainActor
class CitySearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchText = ""
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.0, longitude: 12.5), // Italy center
            span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
        )
    }
    
    func search(_ query: String) {
        searchText = query
        if query.isEmpty {
            results = []
            isSearching = false
        } else {
            isSearching = true
            completer.queryFragment = query
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Filter to show mainly cities/regions
        results = completer.results.filter { result in
            // Exclude specific addresses (with numbers)
            !result.title.contains(where: { $0.isNumber })
        }
        isSearching = false
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
        isSearching = false
    }
    
    func getCoordinate(for result: MKLocalSearchCompletion) async -> MKCoordinateRegion? {
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                // iOS 26+: location is non-optional
                let location = item.location
                return MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }
        } catch {
            print("Search error: \(error.localizedDescription)")
        }
        return nil
    }
}

struct CitySearchView: View {
    @StateObject private var searchCompleter = CitySearchCompleter()
    @Binding var isPresented: Bool
    let onCitySelected: (MKCoordinateRegion, String) -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search city or region...", text: Binding(
                        get: { searchCompleter.searchText },
                        set: { searchCompleter.search($0) }
                    ))
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    
                    if !searchCompleter.searchText.isEmpty {
                        Button {
                            searchCompleter.search("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                Divider()
                
                // Results list
                if searchCompleter.isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 40)
                    Spacer()
                } else if searchCompleter.results.isEmpty && !searchCompleter.searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No results found")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else if searchCompleter.results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.appAccent.opacity(0.6))
                        
                        Text("Search for a city")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        
                        Text("Find hidden places in any city or region")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchCompleter.results, id: \.self) { result in
                                Button {
                                    selectCity(result)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.appAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .font(.body.weight(.medium))
                                                .foregroundColor(.white)
                                            
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.clear)
                                }
                                
                                Divider()
                                    .padding(.leading, 50)
                            }
                        }
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private func selectCity(_ result: MKLocalSearchCompletion) {
        Task {
            if let region = await searchCompleter.getCoordinate(for: result) {
                let cityName = result.title
                onCitySelected(region, cityName)
                isPresented = false
            }
        }
    }
}

#Preview {
    CitySearchView(isPresented: .constant(true)) { region, name in
        print("Selected: \(name)")
    }
}
