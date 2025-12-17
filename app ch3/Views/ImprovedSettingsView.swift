//
//  ImprovedSettingsView.swift
//  app ch3
//
//  Settings view - simplified to show only app version
//

import SwiftUI

struct ImprovedSettingsView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // App version
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discover Secret Places")
                                .font(.headline)
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("App Info")
                }
            }
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ImprovedSettingsView(viewModel: PlacesViewModel())
}
