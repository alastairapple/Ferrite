//
//  UnchainedPluginView.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import SwiftUI

struct UnchainedPluginView: View {
    @EnvironmentObject var pluginManager: PluginManager
    @EnvironmentObject var logManager: LoggingManager
    
    @State private var unchainedUrl = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Info"
    
    @State private var importedPlugins: [UnchainedPluginJson] = []
    @State private var showPluginsList = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unchained Plugin Import")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Import search plugins from Unchained Android debrid management app. These plugins often perform much better than native plugins.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plugin URL")
                        .font(.headline)
                    
                    TextField("Enter Unchained plugin URL", text: $unchainedUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Text("Enter the direct URL to an Unchained plugin JSON file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    Task {
                        await importUnchainedPlugin()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Importing..." : "Import Plugin")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidUrl && !isLoading ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isValidUrl || isLoading)
                
                if !importedPlugins.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Imported Plugins (\(importedPlugins.count))")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Show Details") {
                                showPluginsList = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                            ForEach(importedPlugins.prefix(3), id: \.name) { plugin in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plugin.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(plugin.author ?? "Unknown Author")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        if importedPlugins.count > 3 {
                            Text("+ \(importedPlugins.count - 3) more plugins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Popular Unchained Sources")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(popularUnchainedSources, id: \.name) { source in
                            Button(action: {
                                unchainedUrl = source.url
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(source.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Unchained Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showPluginsList) {
            UnchainedPluginListView(plugins: importedPlugins)
        }
    }
    
    private var isValidUrl: Bool {
        !unchainedUrl.isEmpty && (unchainedUrl.hasPrefix("http://") || unchainedUrl.hasPrefix("https://"))
    }
    
    private var popularUnchainedSources: [PopularSource] {
        [
            PopularSource(
                name: "1337x Unchained",
                description: "Popular torrent tracker with high-quality releases",
                url: "https://example.com/1337x-unchained.json"
            ),
            PopularSource(
                name: "RARBG Unchained",
                description: "High-quality movie and TV show torrents",
                url: "https://example.com/rarbg-unchained.json"
            ),
            PopularSource(
                name: "Nyaa Unchained",
                description: "Anime and Asian media torrents",
                url: "https://example.com/nyaa-unchained.json"
            )
        ]
    }
    
    private func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    private func importUnchainedPlugin() async {
        isLoading = true
        
        do {
            try await pluginManager.fetchUnchainedPlugins(from: unchainedUrl)
            
            alertTitle = "Success"
            alertMessage = "Unchained plugin imported successfully!"
            showAlert = true
            
            // Clear the input
            unchainedUrl = ""
            
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to import Unchained plugin: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
}

struct PopularSource {
    let name: String
    let description: String
    let url: String
}

struct UnchainedPluginListView: View {
    let plugins: [UnchainedPluginJson]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(plugins, id: \.name) { plugin in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(plugin.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("v\(plugin.version)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .cornerRadius(4)
                        }
                        
                        if let author = plugin.author {
                            Text("by \(author)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let description = plugin.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        
                        if let website = plugin.website {
                            Link(destination: URL(string: website)!) {
                                Text(website)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Imported Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
}

struct UnchainedPluginView_Previews: PreviewProvider {
    static var previews: some View {
        UnchainedPluginView()
            .environmentObject(PluginManager())
            .environmentObject(LoggingManager())
    }
}