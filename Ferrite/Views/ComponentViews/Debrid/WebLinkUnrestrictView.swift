//
//  WebLinkUnrestrictView.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import SwiftUI

struct WebLinkUnrestrictView: View {
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var pluginManager: PluginManager
    
    @State private var webLink = ""
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Error"
    
    private var isValidLink: Bool {
        !webLink.isEmpty && (webLink.hasPrefix("http://") || webLink.hasPrefix("https://"))
    }
    
    private var isSupportedLink: Bool {
        isValidLink && debridManager.isWebLinkSupported(webLink)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Web Link")
                        .font(.headline)
                    
                    TextField("Enter download link", text: $webLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !webLink.isEmpty {
                        HStack {
                            Image(systemName: isValidLink ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isValidLink ? .green : .red)
                            
                            Text(isValidLink ? "Valid URL format" : "Invalid URL format")
                                .font(.caption)
                                .foregroundColor(isValidLink ? .green : .red)
                        }
                        
                        if isValidLink {
                            HStack {
                                Image(systemName: isSupportedLink ? "checkmark.circle.fill" : "questionmark.circle.fill")
                                    .foregroundColor(isSupportedLink ? .green : .orange)
                                
                                Text(isSupportedLink ? "Supported host" : "Host support unknown")
                                    .font(.caption)
                                    .foregroundColor(isSupportedLink ? .green : .orange)
                            }
                        }
                    }
                }
                
                Button(action: {
                    Task {
                        await unrestrictLink()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isProcessing ? "Processing..." : "Unrestrict Link")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidLink && !isProcessing ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isValidLink || isProcessing)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supported Hosts")
                        .font(.headline)
                    
                    Text("Popular supported hosts include:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(sampleHosts, id: \.self) { host in
                            Text(host)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .cornerRadius(6)
                        }
                    }
                    
                    if let realDebrid = debridManager.selectedDebridSource as? RealDebrid,
                       !realDebrid.supportedHosts.isEmpty {
                        Text("\(realDebrid.supportedHosts.count) hosts currently supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Unrestrict Web Link")
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
    }
    
    private var sampleHosts: [String] {
        ["rapidgator.net", "uploaded.net", "nitroflare.com", "turbobit.net", "1fichier.com", "mediafire.com"]
    }
    
    private func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    private func unrestrictLink() async {
        isProcessing = true
        
        if let unrestrictedUrl = await debridManager.unrestrictWebLink(webLink) {
            alertTitle = "Success"
            alertMessage = "Link unrestricted successfully! The file has been added to your downloads."
            showAlert = true
            
            // Optionally trigger default action
            await MainActor.run {
                pluginManager.runDefaultAction(urlString: unrestrictedUrl, navModel: navModel)
            }
            
            // Clear the input
            webLink = ""
        } else {
            alertTitle = "Error"
            alertMessage = "Failed to unrestrict the link. Please check if the link is valid and supported."
            showAlert = true
        }
        
        isProcessing = false
    }
}

struct WebLinkUnrestrictView_Previews: PreviewProvider {
    static var previews: some View {
        WebLinkUnrestrictView()
            .environmentObject(DebridManager())
            .environmentObject(NavigationViewModel())
            .environmentObject(PluginManager())
    }
}