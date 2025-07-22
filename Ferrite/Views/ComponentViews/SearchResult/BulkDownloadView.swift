//
//  BulkDownloadView.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import SwiftUI

struct BulkDownloadView: View {
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var scrapingModel: ScrapingViewModel
    @EnvironmentObject var navModel: NavigationViewModel
    
    @State private var selectedResults: Set<SearchResult> = []
    @State private var isSelectMode = false
    @State private var showConfirmation = false
    
    private var filteredResults: [SearchResult] {
        scrapingModel.searchResults.filter { result in
            // Only show results that have magnet links
            result.magnet.link != nil
        }
    }
    
    private var selectedMagnets: [Magnet] {
        Array(selectedResults).map { $0.magnet }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if filteredResults.isEmpty {
                    ContentUnavailableView(
                        "No Downloads Available",
                        systemImage: "tray",
                        description: Text("Search for content first to see bulk download options.")
                    )
                } else {
                    List {
                        ForEach(filteredResults, id: \.self) { result in
                            HStack {
                                if isSelectMode {
                                    Button(action: {
                                        if selectedResults.contains(result) {
                                            selectedResults.remove(result)
                                        } else {
                                            selectedResults.insert(result)
                                        }
                                    }) {
                                        Image(systemName: selectedResults.contains(result) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedResults.contains(result) ? .accentColor : .gray)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title ?? "Unknown")
                                        .font(.body)
                                        .lineLimit(2)
                                    
                                    HStack {
                                        Text(result.source)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if let seeders = result.seeders, seeders > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "arrow.up")
                                                    .font(.caption2)
                                                Text("\(seeders)")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.green)
                                        }
                                        
                                        if let size = result.size {
                                            Text(size)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelectMode {
                                    if selectedResults.contains(result) {
                                        selectedResults.remove(result)
                                    } else {
                                        selectedResults.insert(result)
                                    }
                                }
                            }
                        }
                    }
                    
                    if isSelectMode && !selectedResults.isEmpty {
                        VStack(spacing: 12) {
                            Text("\(selectedResults.count) item\(selectedResults.count == 1 ? "" : "s") selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Button("Select All") {
                                    selectedResults = Set(filteredResults)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Clear Selection") {
                                    selectedResults.removeAll()
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Button("Add \(selectedResults.count) to Queue") {
                                    showConfirmation = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                    }
                }
            }
            .navigationTitle("Bulk Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredResults.isEmpty {
                        Button(isSelectMode ? "Done" : "Select") {
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedResults.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Add \(selectedResults.count) downloads to queue?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Add to Download Queue") {
                Task {
                    await debridManager.addMagnetsToQueue(selectedMagnets)
                    dismiss()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will add \(selectedResults.count) magnet\(selectedResults.count == 1 ? "" : "s") to your Real-Debrid download queue.")
        }
    }
    
    private func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
}

struct BulkDownloadView_Previews: PreviewProvider {
    static var previews: some View {
        BulkDownloadView()
            .environmentObject(DebridManager())
            .environmentObject(ScrapingViewModel())
            .environmentObject(NavigationViewModel())
    }
}