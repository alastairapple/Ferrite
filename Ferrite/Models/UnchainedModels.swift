//
//  UnchainedModels.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import Foundation

// MARK: - Unchained Plugin Format Support

/// Represents an Unchained search plugin configuration
struct UnchainedPluginJson: Codable, Hashable, Sendable {
    let name: String
    let version: String
    let author: String?
    let description: String?
    let website: String?
    let searchUrl: String
    let loginUrl: String?
    let loginRequired: Bool?
    let categories: [UnchainedCategory]?
    let search: UnchainedSearchConfig
    let results: UnchainedResultsConfig
    
    // Unchained specific fields
    let userAgent: String?
    let encoding: String?
    let timeout: Int?
    let cookies: [String: String]?
    let headers: [String: String]?
}

struct UnchainedCategory: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
}

struct UnchainedSearchConfig: Codable, Hashable, Sendable {
    let paths: [UnchainedSearchPath]
    let inputs: [UnchainedSearchInput]?
    let keywordsParam: String?
    let categoriesParam: String?
    let rows: UnchainedResultsSelector?
    
    enum CodingKeys: String, CodingKey {
        case paths, inputs
        case keywordsParam = "keywords_param"
        case categoriesParam = "categories_param"
        case rows
    }
}

struct UnchainedSearchPath: Codable, Hashable, Sendable {
    let path: String
    let method: String?
    let followRedirect: Bool?
    
    enum CodingKeys: String, CodingKey {
        case path, method
        case followRedirect = "follow_redirect"
    }
}

struct UnchainedSearchInput: Codable, Hashable, Sendable {
    let name: String
    let type: String
    let value: String?
}

struct UnchainedResultsConfig: Codable, Hashable, Sendable {
    let selector: String?
    let fields: [UnchainedFieldSelector]
}

struct UnchainedResultsSelector: Codable, Hashable, Sendable {
    let selector: String
    let attribute: String?
}

struct UnchainedFieldSelector: Codable, Hashable, Sendable {
    let name: String
    let selector: String
    let attribute: String?
    let filters: [UnchainedFilter]?
    let optional: Bool?
}

struct UnchainedFilter: Codable, Hashable, Sendable {
    let name: String
    let args: [String]?
}

// MARK: - Conversion Extensions

extension UnchainedPluginJson {
    /// Converts an Unchained plugin to Ferrite's SourceJson format
    func toFerriteSource() -> SourceJson? {
        // Convert Unchained search config to Ferrite HTML parser
        let htmlParser = convertToHtmlParser()
        
        return SourceJson(
            name: name,
            version: Int16(version.components(separatedBy: ".").first.flatMap(Int.init) ?? 1),
            minVersion: nil,
            about: description,
            website: website ?? searchUrl,
            dynamicWebsite: false,
            fallbackUrls: nil,
            trackers: nil,
            api: nil,
            jsonParser: nil,
            rssParser: nil,
            htmlParser: htmlParser,
            author: author,
            listId: nil,
            listName: "Unchained Compatible",
            tags: [PluginTagJson(name: "Unchained", colorHex: "#FF6B35")]
        )
    }
    
    private func convertToHtmlParser() -> SourceHtmlParserJson? {
        guard let rowsSelector = search.rows?.selector ?? results.selector else {
            return nil
        }
        
        // Build search URL with parameters
        var searchUrlWithParams = searchUrl
        if let keywordsParam = search.keywordsParam {
            searchUrlWithParams += (searchUrlWithParams.contains("?") ? "&" : "?") + "\(keywordsParam)={query}"
        }
        
        // Find field selectors
        let titleField = results.fields.first { $0.name.lowercased().contains("title") || $0.name.lowercased().contains("name") }
        let sizeField = results.fields.first { $0.name.lowercased().contains("size") }
        let seedersField = results.fields.first { $0.name.lowercased().contains("seed") }
        let leechersField = results.fields.first { $0.name.lowercased().contains("leech") || $0.name.lowercased().contains("peer") }
        let magnetField = results.fields.first { $0.name.lowercased().contains("magnet") || $0.name.lowercased().contains("download") }
        
        guard let titleField = titleField else {
            return nil
        }
        
        // Create title selector
        let titleSelector = SourceTitleJson(
            query: titleField.selector,
            attribute: titleField.attribute,
            regex: nil,
            discriminator: nil
        )
        
        // Create magnet selector
        let magnetSelector = SourceMagnetLinkJson(
            query: magnetField?.selector ?? "a[href*='magnet:']",
            attribute: magnetField?.attribute ?? "href",
            regex: nil,
            externalLinkQuery: nil,
            discriminator: nil
        )
        
        // Create size selector if available
        var sizeSelector: SourceSizeJson?
        if let sizeField = sizeField {
            sizeSelector = SourceSizeJson(
                query: sizeField.selector,
                attribute: sizeField.attribute,
                regex: nil,
                discriminator: nil
            )
        }
        
        // Create seed/leech selectors if available
        var seedLeechSelector: SourceSeedLeechJson?
        if let seedersField = seedersField {
            seedLeechSelector = SourceSeedLeechJson(
                seeders: seedersField.selector,
                leechers: leechersField?.selector,
                combined: nil,
                attribute: seedersField.attribute,
                discriminator: nil,
                seederRegex: nil,
                leecherRegex: nil
            )
        }
        
        // Create request configuration
        var requestConfig: SourceRequestJson?
        if let headers = headers, !headers.isEmpty {
            requestConfig = SourceRequestJson(
                method: search.paths.first?.method ?? "GET",
                headers: headers,
                body: nil
            )
        }
        
        return SourceHtmlParserJson(
            searchUrl: searchUrlWithParams,
            rows: rowsSelector,
            title: titleSelector,
            size: sizeSelector,
            sl: seedLeechSelector,
            magnet: magnetSelector,
            subName: nil,
            request: requestConfig
        )
    }
}

// MARK: - Unchained Plugin Manager Extension

extension PluginManager {
    /// Fetches and installs Unchained-compatible plugins
    func fetchUnchainedPlugins(from urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw PluginManagerError.PluginFetch(description: "Invalid Unchained plugin URL")
        }
        
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
        
        // Try to parse as Unchained plugin format
        let unchainedPlugin = try JSONDecoder().decode(UnchainedPluginJson.self, from: data)
        
        // Convert to Ferrite source format
        guard let ferriteSource = unchainedPlugin.toFerriteSource() else {
            throw PluginManagerError.PluginFetch(description: "Could not convert Unchained plugin to Ferrite format")
        }
        
        // Install the converted source
        await installSource(sourceJson: ferriteSource, doUpsert: true)
        
        await logManager?.info("Successfully installed Unchained plugin: \(unchainedPlugin.name)")
    }
    
    /// Checks if a URL contains an Unchained plugin
    func isUnchainedPlugin(url: URL) async -> Bool {
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let _ = try JSONDecoder().decode(UnchainedPluginJson.self, from: data)
            return true
        } catch {
            return false
        }
    }
}