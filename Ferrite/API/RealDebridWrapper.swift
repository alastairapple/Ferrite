//
//  RealDebridWrapper.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/7/22.
//

import Foundation

class RealDebrid: PollingDebridSource, ObservableObject {
    let id = "RealDebrid"
    let abbreviation = "RD"
    let website = "https://real-debrid.com"
    let description: String? = "RealDebrid is a debrid service that is used for downloads and media playback. " +
        "You must pay to access this service. \n\n" +
        "It is not recommended to use this service since media cache checks are not possible via the API. " +
        "Ferrite's instant availability solely looks at a user's magnet library. \n\n" +
        "If you must use this service, it is recommended to download search results manually using the context menu. \n\n" +
        "This service does not inform if a magnet link is a batch before downloading."

    let cachedStatus: [String] = ["downloaded"]
    var authTask: Task<Void, Error>?

    @Published var authProcessing: Bool = false

    // Check the manual token since getTokens() is async
    var isLoggedIn: Bool {
        FerriteKeychain.shared.get("RealDebrid.AccessToken") != nil
    }

    var manualToken: String? {
        if UserDefaults.standard.bool(forKey: "RealDebrid.UseManualKey") {
            return FerriteKeychain.shared.get("RealDebrid.AccessToken")
        } else {
            return nil
        }
    }

    @Published var IAValues: [DebridIA] = []
    @Published var cloudDownloads: [DebridCloudDownload] = []
    @Published var cloudMagnets: [DebridCloudMagnet] = []
    @Published var supportedHosts: [HostsResponse] = []
    var cloudTTL: Double = 0.0

    private let baseAuthUrl = "https://api.real-debrid.com/oauth/v2"
    private let baseApiUrl = "https://api.real-debrid.com/rest/1.0"
    private let openSourceClientId = "X245A4XAIBGVM"

    private let jsonDecoder = JSONDecoder()

    @MainActor
    private func setUserDefaultsValue(_ value: Any, forKey: String) {
        UserDefaults.standard.set(value, forKey: forKey)
    }

    @MainActor
    private func removeUserDefaultsValue(forKey: String) {
        UserDefaults.standard.removeObject(forKey: forKey)
    }

    init() {
        // Populate user downloads and magnets
        Task {
            try? await getUserDownloads()
            try? await getUserMagnets()
            try? await getSupportedHosts()
        }
    }

    // MARK: - Auth

    // Fetches the device code from RD
    func getAuthUrl() async throws -> URL {
        var urlComponents = URLComponents(string: "\(baseAuthUrl)/device/code")!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: openSourceClientId),
            URLQueryItem(name: "new_credentials", value: "yes")
        ]

        guard let url = urlComponents.url else {
            throw DebridError.InvalidUrl
        }

        let request = URLRequest(url: url)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Validate the URL before doing anything else
            let rawResponse = try jsonDecoder.decode(DeviceCodeResponse.self, from: data)
            guard let directVerificationUrl = URL(string: rawResponse.directVerificationURL) else {
                throw DebridError.AuthQuery(description: "The verification URL is invalid")
            }

            // Spawn the polling task separately
            authTask = Task {
                try await getDeviceCredentials(deviceCode: rawResponse.deviceCode)
            }

            return directVerificationUrl
        } catch {
            print("Couldn't get the new client creds!")
            throw DebridError.AuthQuery(description: error.localizedDescription)
        }
    }

    // Fetches the user's client ID and secret
    func getDeviceCredentials(deviceCode: String) async throws {
        var urlComponents = URLComponents(string: "\(baseAuthUrl)/device/credentials")!
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: openSourceClientId),
            URLQueryItem(name: "code", value: deviceCode)
        ]

        guard let url = urlComponents.url else {
            throw DebridError.InvalidUrl
        }

        let request = URLRequest(url: url)

        // Timer to poll RD API for credentials
        var count = 0

        while count < 12 {
            if Task.isCancelled {
                throw DebridError.AuthQuery(description: "Token request cancelled.")
            }

            let (data, _) = try await URLSession.shared.data(for: request)

            // We don't care if this fails
            let rawResponse = try? jsonDecoder.decode(DeviceCredentialsResponse.self, from: data)

            // If there's a client ID from the response, end the task successfully
            if let clientId = rawResponse?.clientID, let clientSecret = rawResponse?.clientSecret {
                await setUserDefaultsValue(clientId, forKey: "RealDebrid.ClientId")
                FerriteKeychain.shared.set(clientSecret, forKey: "RealDebrid.ClientSecret")

                try await getApiTokens(deviceCode: deviceCode)

                return
            } else {
                try await Task.sleep(seconds: 5)
                count += 1
            }
        }

        throw DebridError.AuthQuery(description: "Could not fetch the client ID and secret in time. Try logging in again.")
    }

    // Fetch all tokens for the user and store in FerriteKeychain.shared
    func getApiTokens(deviceCode: String) async throws {
        guard let clientId = UserDefaults.standard.string(forKey: "RealDebrid.ClientId") else {
            throw DebridError.EmptyData
        }

        guard let clientSecret = FerriteKeychain.shared.get("RealDebrid.ClientSecret") else {
            throw DebridError.EmptyData
        }

        var request = URLRequest(url: URL(string: "\(baseAuthUrl)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "code", value: deviceCode),
            URLQueryItem(name: "grant_type", value: "http://oauth.net/grant_type/device/1.0")
        ]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        let rawResponse = try jsonDecoder.decode(TokenResponse.self, from: data)

        FerriteKeychain.shared.set(rawResponse.accessToken, forKey: "RealDebrid.AccessToken")
        FerriteKeychain.shared.set(rawResponse.refreshToken, forKey: "RealDebrid.RefreshToken")

        let accessTimestamp = Date().timeIntervalSince1970 + Double(rawResponse.expiresIn)
        await setUserDefaultsValue(accessTimestamp, forKey: "RealDebrid.AccessTokenStamp")
    }

    func getToken() async -> String? {
        let accessTokenStamp = UserDefaults.standard.double(forKey: "RealDebrid.AccessTokenStamp")

        if Date().timeIntervalSince1970 > accessTokenStamp {
            do {
                if let refreshToken = FerriteKeychain.shared.get("RealDebrid.RefreshToken") {
                    try await getApiTokens(deviceCode: refreshToken)
                }
            } catch {
                print(error)
                return nil
            }
        }

        return FerriteKeychain.shared.get("RealDebrid.AccessToken")
    }

    // Adds a manual API key instead of web auth
    // Clear out existing refresh tokens and timestamps
    func setApiKey(_ key: String) {
        FerriteKeychain.shared.set(key, forKey: "RealDebrid.AccessToken")
        FerriteKeychain.shared.delete("RealDebrid.RefreshToken")
        FerriteKeychain.shared.delete("RealDebrid.AccessTokenStamp")

        UserDefaults.standard.set(true, forKey: "RealDebrid.UseManualKey")
    }

    // Deletes tokens from device and RD's servers
    func logout() async {
        FerriteKeychain.shared.delete("RealDebrid.RefreshToken")
        FerriteKeychain.shared.delete("RealDebrid.ClientSecret")
        await removeUserDefaultsValue(forKey: "RealDebrid.ClientId")
        await removeUserDefaultsValue(forKey: "RealDebrid.AccessTokenStamp")

        // Run the request, doesn't matter if it fails
        if let token = FerriteKeychain.shared.get("RealDebrid.AccessToken") {
            var request = URLRequest(url: URL(string: "\(baseApiUrl)/disable_access_token")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)

            FerriteKeychain.shared.delete("RealDebrid.AccessToken")
            await removeUserDefaultsValue(forKey: "RealDebrid.UseManualKey")
        }
    }

    // MARK: - Common request

    // Wrapper request function which matches the responses and returns data
    @discardableResult private func performRequest(request: inout URLRequest, requestName: String) async throws -> Data {
        guard let token = await getToken() else {
            throw DebridError.InvalidToken
        }

        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw DebridError.FailedRequest(description: "No HTTP response given")
        }

        if response.statusCode >= 200, response.statusCode <= 299 {
            return data
        } else if response.statusCode == 401 {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed because you were unauthorized. Please relogin to RealDebrid in Settings.")
        } else {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed with status code \(response.statusCode).")
        }
    }

    // MARK: - Instant availability

    // Post-API changes
    // Use user magnets to check for IA instead
    func instantAvailability(magnets: [Magnet]) async throws {
        let now = Date().timeIntervalSince1970

        let sendMagnets = magnets.filter { magnet in
            if let IAIndex = IAValues.firstIndex(where: { $0.magnet.hash == magnet.hash }) {
                if now > IAValues[IAIndex].expiryTimeStamp {
                    IAValues.remove(at: IAIndex)
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        }

        // Fetch the user magnets to the latest version
        try await getUserMagnets()

        for cloudMagnet in cloudMagnets {
            if cachedStatus.contains(cloudMagnet.status),
               sendMagnets.contains(where: { $0.hash == cloudMagnet.hash })
            {
                IAValues.append(
                    DebridIA(
                        magnet: Magnet(hash: cloudMagnet.hash, link: nil),
                        expiryTimeStamp: Date().timeIntervalSince1970 + 300,
                        files: []
                    )
                )
            }
        }
    }

    // MARK: - Downloading

    // Wrapper function to fetch a download link from the API
    func getRestrictedFile(magnet: Magnet, ia: DebridIA?, iaFile: DebridIAFile?) async throws -> (restrictedFile: DebridIAFile?, newIA: DebridIA?) {
        var selectedMagnetId = ""

        do {
            // Don't queue a new job if the magnet already exists in the user's library
            if let existingCloudMagnet = cloudMagnets.first(where: {
                $0.hash == magnet.hash && cachedStatus.contains($0.status)
            }) {
                selectedMagnetId = existingCloudMagnet.id
            } else {
                selectedMagnetId = try await addMagnet(magnet: magnet)

                try await selectFiles(debridID: selectedMagnetId, fileIds: iaFile?.batchIds ?? [])
            }

            let response = try await torrentInfo(debridID: selectedMagnetId)
            let filteredFiles = response.files.filter { $0.selected == 1 }

            // Need to return this to the user
            if filteredFiles.count > 1, iaFile == nil {
                var copiedIA = ia

                copiedIA?.files = response.files.enumerated().compactMap { index, file in
                    DebridIAFile(
                        id: index,
                        name: file.path,
                        streamUrlString: response.links[safe: index]
                    )
                }

                return (nil, copiedIA)
            }

            // RealDebrid has 1 as the first ID for a file
            let selectedFileId = iaFile?.id ?? 1
            let linkIndex = filteredFiles.firstIndex(where: { $0.id == selectedFileId })

            guard let cloudMagnetLink = response.links[safe: linkIndex ?? -1] else {
                throw DebridError.EmptyUserMagnets
            }

            let restrictedFile = DebridIAFile(id: 0, name: response.filename, streamUrlString: cloudMagnetLink)
            return (restrictedFile, nil)
        } catch {
            if case DebridError.EmptyUserMagnets = error, !selectedMagnetId.isEmpty {
                try? await deleteUserMagnet(cloudMagnetId: selectedMagnetId)
            }

            // Re-raise the error to the calling function
            throw error
        }
    }

    // Adds a magnet link to the user's RD account
    func addMagnet(magnet: Magnet) async throws -> String {
        guard let magnetLink = magnet.link else {
            throw DebridError.FailedRequest(description: "The magnet link is invalid")
        }

        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents/addMagnet")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "magnet", value: magnetLink)]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(AddMagnetResponse.self, from: data)

        return rawResponse.id
    }

    // Queues the magnet link for downloading
    func selectFiles(debridID: String, fileIds: [Int]) async throws {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents/selectFiles/\(debridID)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()

        if fileIds.isEmpty {
            bodyComponents.queryItems = [URLQueryItem(name: "files", value: "all")]
        } else {
            let joinedIds = fileIds.map(String.init).joined(separator: ",")
            bodyComponents.queryItems = [URLQueryItem(name: "files", value: joinedIds)]
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        try await performRequest(request: &request, requestName: #function)
    }

    // Gets the info of a torrent from a given ID
    func torrentInfo(debridID: String) async throws -> TorrentInfoResponse {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents/info/\(debridID)")!)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TorrentInfoResponse.self, from: data)

        // Let the user know if a magnet is downloading
        switch rawResponse.status {
        case "downloaded":
            return rawResponse
        case "downloading", "queued":
            throw DebridError.IsCaching
        default:
            throw DebridError.EmptyUserMagnets
        }
    }

    // Downloads link from selectFiles for playback
    func unrestrictFile(_ restrictedFile: DebridIAFile) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/unrestrict/link")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "link", value: restrictedFile.streamUrlString)]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(UnrestrictLinkResponse.self, from: data)

        return rawResponse.download
    }

    // MARK: - Cloud methods

    // Gets the user's cloud magnet library
    func getUserMagnets() async throws {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents")!)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode([UserTorrentsResponse].self, from: data)
        cloudMagnets = rawResponse.map { response in
            DebridCloudMagnet(
                id: response.id,
                fileName: response.filename,
                status: response.status,
                hash: response.hash,
                links: [response.id]
            )
        }
    }

    // Deletes a magnet download from RD
    func deleteUserMagnet(cloudMagnetId: String?) async throws {
        let deleteId: String

        if let cloudMagnetId {
            deleteId = cloudMagnetId
        } else {
            // Refresh the user magnet list
            // The first file is the currently caching one
            let _ = try await getUserMagnets()
            guard let firstCloudMagnet = cloudMagnets[safe: -1] else {
                throw DebridError.EmptyUserMagnets
            }

            deleteId = firstCloudMagnet.id
        }

        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents/delete/\(deleteId)")!)
        request.httpMethod = "DELETE"

        try await performRequest(request: &request, requestName: #function)
    }

    // Gets the user's downloads
    func getUserDownloads() async throws {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/downloads")!)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode([UserDownloadsResponse].self, from: data)
        cloudDownloads = rawResponse.map { response in
            DebridCloudDownload(id: response.id, fileName: response.filename, link: response.download)
        }
    }

    // Not used
    func checkUserDownloads(link: String) -> String? {
        link
    }

    func deleteUserDownload(downloadId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/downloads/delete/\(downloadId)")!)
        request.httpMethod = "DELETE"

        try await performRequest(request: &request, requestName: #function)
    }

    // MARK: - Enhanced debrid management methods

    // Uploads a torrent file to Real-Debrid
    func uploadTorrentFile(fileData: Data, filename: String) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/torrents/addTorrent")!)
        request.httpMethod = "PUT"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        
        // Add the torrent file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"torrent\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/x-bittorrent\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(UploadTorrentResponse.self, from: data)

        return rawResponse.id
    }

    // Unrestricts a web download link
    func unrestrictWebLink(_ webLink: String) async throws -> WebLinkUnrestrictResponse {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/unrestrict/link")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "link", value: webLink)]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(WebLinkUnrestrictResponse.self, from: data)

        return rawResponse
    }

    // Gets transcoding information for a download link
    func getTranscodingInfo(downloadId: String) async throws -> TranscodingResponse {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/streaming/transcode/\(downloadId)")!)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TranscodingResponse.self, from: data)

        return rawResponse
    }

    // Gets transcoding media URL
    func getTranscodingUrl(downloadId: String, format: String = "apple") async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/streaming/mediaInfos/\(downloadId)")!)

        let data = try await performRequest(request: &request, requestName: #function)
        
        // Parse the response to get the transcoding URL
        // This is a simplified implementation - the actual API response may differ
        if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let transcodingUrl = jsonResponse[format] as? String {
            return transcodingUrl
        }
        
        throw DebridError.FailedRequest(description: "Could not get transcoding URL for format \(format)")
    }

    // Gets list of supported hosts for web link unrestricting
    func getSupportedHosts() async throws {
        var request = URLRequest(url: URL(string: "\(baseApiUrl)/hosts")!)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode([HostsResponse].self, from: data)
        
        supportedHosts = rawResponse.filter { $0.status == "up" }
    }

    // Check if a web link is supported by Real-Debrid
    func isWebLinkSupported(_ webLink: String) -> Bool {
        guard let url = URL(string: webLink),
              let host = url.host?.lowercased() else {
            return false
        }
        
        return supportedHosts.contains { $0.host.lowercased().contains(host) || host.contains($0.host.lowercased()) }
    }

    // Batch add multiple magnets
    func addMagnets(_ magnets: [Magnet]) async throws -> [String] {
        var torrentIds: [String] = []
        
        for magnet in magnets {
            do {
                let torrentId = try await addMagnet(magnet: magnet)
                torrentIds.append(torrentId)
            } catch {
                // Continue with other magnets even if one fails
                print("Failed to add magnet \(magnet.hash ?? "unknown"): \(error)")
            }
        }
        
        return torrentIds
    }

    // Enhanced cloud management with filtering
    func getFilteredDownloads(searchText: String = "", fileType: String = "") -> [DebridCloudDownload] {
        return cloudDownloads.filter { download in
            let matchesSearch = searchText.isEmpty || download.fileName.lowercased().contains(searchText.lowercased())
            let matchesType = fileType.isEmpty || download.fileName.lowercased().hasSuffix(fileType.lowercased())
            return matchesSearch && matchesType
        }
    }

    func getFilteredMagnets(searchText: String = "", status: String = "") -> [DebridCloudMagnet] {
        return cloudMagnets.filter { magnet in
            let matchesSearch = searchText.isEmpty || magnet.fileName.lowercased().contains(searchText.lowercased())
            let matchesStatus = status.isEmpty || magnet.status == status
            return matchesSearch && matchesStatus
        }
    }
}
