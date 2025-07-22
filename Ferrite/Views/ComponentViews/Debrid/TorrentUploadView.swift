//
//  TorrentUploadView.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct TorrentUploadView: View {
    @EnvironmentObject var debridManager: DebridManager
    
    @State private var showFilePicker = false
    @State private var selectedFiles: [URL] = []
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Info"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upload Torrent Files")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select .torrent files from your device to add them to your Real-Debrid account.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showFilePicker = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        Text("Select Torrent Files")
                            .font(.headline)
                        
                        Text("Tap to browse for .torrent files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                }
                .disabled(isUploading)
                
                if !selectedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Files (\(selectedFiles.count))")
                            .font(.headline)
                        
                        ForEach(selectedFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.accentColor)
                                
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedFiles.removeAll { $0 == file }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: {
                        Task {
                            await uploadFiles()
                        }
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isUploading ? "Uploading..." : "Upload \(selectedFiles.count) file\(selectedFiles.count == 1 ? "" : "s")")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isUploading)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Upload Requirements")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Files must be .torrent format")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Maximum file size: 1MB")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Valid torrent files only")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
            .navigationTitle("Upload Torrents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.item], // Will filter for .torrent in validation
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let torrentFiles = urls.filter { $0.pathExtension.lowercased() == "torrent" }
                if torrentFiles.isEmpty {
                    alertTitle = "Invalid Files"
                    alertMessage = "Please select only .torrent files."
                    showAlert = true
                } else {
                    selectedFiles = torrentFiles
                }
            case .failure(let error):
                alertTitle = "Error"
                alertMessage = "Failed to access files: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    private func uploadFiles() async {
        isUploading = true
        var successCount = 0
        
        for fileUrl in selectedFiles {
            do {
                // Check file access
                guard fileUrl.startAccessingSecurityScopedResource() else {
                    continue
                }
                defer { fileUrl.stopAccessingSecurityScopedResource() }
                
                let fileData = try Data(contentsOf: fileUrl)
                let filename = fileUrl.lastPathComponent
                
                // Validate file size (1MB limit)
                guard fileData.count <= 1024 * 1024 else {
                    continue
                }
                
                await debridManager.uploadTorrentFile(fileData: fileData, filename: filename)
                successCount += 1
                
            } catch {
                // Continue with next file
                continue
            }
        }
        
        isUploading = false
        
        if successCount > 0 {
            alertTitle = "Success"
            alertMessage = "Successfully uploaded \(successCount) of \(selectedFiles.count) torrent file\(selectedFiles.count == 1 ? "" : "s")."
            selectedFiles.removeAll()
        } else {
            alertTitle = "Error"
            alertMessage = "Failed to upload any torrent files. Please check the files and try again."
        }
        
        showAlert = true
    }
}

struct TorrentUploadView_Previews: PreviewProvider {
    static var previews: some View {
        TorrentUploadView()
            .environmentObject(DebridManager())
    }
}