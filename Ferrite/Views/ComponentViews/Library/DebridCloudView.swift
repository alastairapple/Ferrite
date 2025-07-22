//
//  DebridCloudView.swift
//  Ferrite
//
//  Created by Brian Dashore on 12/31/22.
//

import SwiftUI

struct DebridCloudView: View {
    @EnvironmentObject var debridManager: DebridManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    
    @State private var showWebLinkSheet = false
    @State private var showTorrentUploadSheet = false
    @State private var selectedFileType = "All"
    @State private var selectedMagnetStatus = "All"
    
    private let fileTypes = ["All", "mp4", "mkv", "avi", "pdf", "zip", "rar"]
    private let magnetStatuses = ["All", "downloaded", "downloading", "queued", "error"]

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced toolbar
            HStack {
                Menu("File Type: \(selectedFileType)") {
                    ForEach(fileTypes, id: \.self) { type in
                        Button(type) {
                            selectedFileType = type
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                Menu("Status: \(selectedMagnetStatus)") {
                    ForEach(magnetStatuses, id: \.self) { status in
                        Button(status) {
                            selectedMagnetStatus = status
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Menu {
                    Button("Add Web Link") {
                        showWebLinkSheet = true
                    }
                    
                    Button("Upload Torrent") {
                        showTorrentUploadSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            List {
                EnhancedCloudDownloadView(
                    debridSource: debridSource, 
                    searchText: $searchText,
                    fileTypeFilter: selectedFileType == "All" ? "" : selectedFileType
                )
                EnhancedCloudMagnetView(
                    debridSource: debridSource, 
                    searchText: $searchText,
                    statusFilter: selectedMagnetStatus == "All" ? "" : selectedMagnetStatus
                )
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $showWebLinkSheet) {
            WebLinkUnrestrictView()
        }
        .sheet(isPresented: $showTorrentUploadSheet) {
            TorrentUploadView()
        }
        .task {
            await debridManager.fetchDebridCloud()
        }
        .refreshable {
            await debridManager.fetchDebridCloud(bypassTTL: true)
        }
        .onChange(of: debridManager.selectedDebridSource?.id) { newType in
            if newType != nil {
                Task {
                    await debridManager.fetchDebridCloud()
                }
            }
        }
    }
}

// Enhanced versions with filtering
struct EnhancedCloudDownloadView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var pluginManager: PluginManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    let fileTypeFilter: String
    
    private var filteredDownloads: [DebridCloudDownload] {
        if let realDebrid = debridSource as? RealDebrid {
            return realDebrid.getFilteredDownloads(searchText: searchText, fileType: fileTypeFilter)
        }
        return debridSource.cloudDownloads.filter {
            searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        DisclosureGroup("Downloads (\(filteredDownloads.count))") {
            ForEach(filteredDownloads, id: \.self) { cloudDownload in
                HStack {
                    Button(cloudDownload.fileName) {
                        navModel.resultFromCloud = true
                        navModel.selectedTitle = cloudDownload.fileName
                        var historyEntry = HistoryEntryJson(
                            name: cloudDownload.fileName,
                            source: debridSource.id
                        )

                        debridManager.currentDebridTask = Task {
                            await debridManager.fetchDebridDownload(magnet: nil, cloudInfo: cloudDownload.link)

                            if !debridManager.downloadUrl.isEmpty {
                                historyEntry.url = debridManager.downloadUrl
                                PersistenceController.shared.createHistory(historyEntry, performSave: true)

                                pluginManager.runDefaultAction(
                                    urlString: debridManager.downloadUrl,
                                    navModel: navModel
                                )
                            }
                        }
                    }
                    .disabledAppearance(navModel.currentChoiceSheet != nil, dimmedOpacity: 0.7, animation: .easeOut(duration: 0.2))
                    .tint(.primary)
                    
                    Spacer()
                    
                    // Add transcoding button for video files
                    if isVideoFile(cloudDownload.fileName) {
                        Menu {
                            Button("Get Apple Transcoding URL") {
                                Task {
                                    await getTranscodingUrl(for: cloudDownload, format: "apple")
                                }
                            }
                            
                            Button("Get Android Transcoding URL") {
                                Task {
                                    await getTranscodingUrl(for: cloudDownload, format: "android")
                                }
                            }
                            
                            Button("Get Chrome Transcoding URL") {
                                Task {
                                    await getTranscodingUrl(for: cloudDownload, format: "chrome")
                                }
                            }
                        } label: {
                            Image(systemName: "tv")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    if let cloudDownload = filteredDownloads[safe: index] {
                        Task {
                            await debridManager.deleteCloudDownload(cloudDownload)
                        }
                    }
                }
            }
        }
    }
    
    private func isVideoFile(_ filename: String) -> Bool {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v"]
        let fileExtension = filename.lowercased().split(separator: ".").last ?? ""
        return videoExtensions.contains(String(fileExtension))
    }
    
    private func getTranscodingUrl(for download: DebridCloudDownload, format: String) async {
        if let transcodingUrl = await debridManager.getTranscodingUrl(downloadId: download.id, format: format) {
            var historyEntry = HistoryEntryJson(
                name: "\(download.fileName) (Transcoded \(format.capitalized))",
                source: debridSource.id
            )
            historyEntry.url = transcodingUrl
            
            PersistenceController.shared.createHistory(historyEntry, performSave: true)
            
            await MainActor.run {
                pluginManager.runDefaultAction(urlString: transcodingUrl, navModel: navModel)
            }
        }
    }
}

struct EnhancedCloudMagnetView: View {
    @EnvironmentObject var debridManager: DebridManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    let statusFilter: String
    
    private var filteredMagnets: [DebridCloudMagnet] {
        if let realDebrid = debridSource as? RealDebrid {
            return realDebrid.getFilteredMagnets(searchText: searchText, status: statusFilter)
        }
        return debridSource.cloudMagnets.filter {
            searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        DisclosureGroup("Magnets (\(filteredMagnets.count))") {
            ForEach(filteredMagnets, id: \.self) { cloudMagnet in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cloudMagnet.fileName)
                            .lineLimit(2)
                        
                        HStack {
                            Text(cloudMagnet.status.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(for: cloudMagnet.status))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .onDelete { offsets in
                for index in offsets {
                    if let cloudMagnet = filteredMagnets[safe: index] {
                        Task {
                            await debridManager.deleteUserMagnet(cloudMagnet)
                        }
                    }
                }
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "downloaded":
            return .green
        case "downloading":
            return .blue
        case "queued":
            return .orange
        case "error":
            return .red
        default:
            return .gray
        }
    }
