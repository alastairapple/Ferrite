//
//  CloudDownloadView.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/6/24.
//

import SwiftUI

struct CloudDownloadView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var pluginManager: PluginManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String

    var body: some View {
        DisclosureGroup("Downloads") {
            ForEach(debridSource.cloudDownloads.filter {
                searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
            }, id: \.self) { cloudDownload in
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
                    if let cloudDownload = debridSource.cloudDownloads[safe: index] {
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
