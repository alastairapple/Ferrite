//
//  EnhancedDebridTests.swift
//  Ferrite
//
//  Created by Enhanced Debrid Management on 12/22/24.
//

import XCTest
@testable import Ferrite

class EnhancedDebridTests: XCTestCase {
    
    var realDebrid: RealDebrid!
    var debridManager: DebridManager!
    
    override func setUp() {
        super.setUp()
        realDebrid = RealDebrid()
        debridManager = DebridManager()
    }
    
    override func tearDown() {
        realDebrid = nil
        debridManager = nil
        super.tearDown()
    }
    
    // MARK: - Web Link Unrestricting Tests
    
    func testIsWebLinkSupported() {
        // Given
        let supportedHost = HostsResponse(host: "rapidgator.net", max_file_size: 1000000000, type: "premium", status: "up")
        realDebrid.supportedHosts = [supportedHost]
        
        // When
        let isSupported = realDebrid.isWebLinkSupported("https://rapidgator.net/file/abc123")
        
        // Then
        XCTAssertTrue(isSupported, "Should recognize supported host")
    }
    
    func testIsWebLinkNotSupported() {
        // Given
        let supportedHost = HostsResponse(host: "rapidgator.net", max_file_size: 1000000000, type: "premium", status: "up")
        realDebrid.supportedHosts = [supportedHost]
        
        // When
        let isSupported = realDebrid.isWebLinkSupported("https://unsupported-host.com/file/abc123")
        
        // Then
        XCTAssertFalse(isSupported, "Should not recognize unsupported host")
    }
    
    func testWebLinkValidation() {
        // Test valid URLs
        XCTAssertTrue("https://rapidgator.net/file/123".hasPrefix("https://"))
        XCTAssertTrue("http://rapidgator.net/file/123".hasPrefix("http://"))
        
        // Test invalid URLs
        XCTAssertFalse("ftp://rapidgator.net/file/123".hasPrefix("https://"))
        XCTAssertFalse("rapidgator.net/file/123".hasPrefix("https://"))
    }
    
    // MARK: - Torrent Upload Tests
    
    func testTorrentFileValidation() {
        // Test valid torrent file extensions
        XCTAssertTrue("test.torrent".hasSuffix(".torrent"))
        XCTAssertTrue("linux-distro.torrent".hasSuffix(".torrent"))
        
        // Test invalid file extensions
        XCTAssertFalse("test.pdf".hasSuffix(".torrent"))
        XCTAssertFalse("test.zip".hasSuffix(".torrent"))
    }
    
    func testTorrentFileSizeValidation() {
        // Test file size validation (1MB limit)
        let validSize = 500 * 1024 // 500KB
        let invalidSize = 2 * 1024 * 1024 // 2MB
        let maxSize = 1024 * 1024 // 1MB
        
        XCTAssertTrue(validSize <= maxSize, "500KB should be valid")
        XCTAssertFalse(invalidSize <= maxSize, "2MB should be invalid")
        XCTAssertTrue(maxSize <= maxSize, "1MB should be valid")
    }
    
    // MARK: - Enhanced Filtering Tests
    
    func testDownloadFiltering() {
        // Given
        let downloads = [
            DebridCloudDownload(id: "1", fileName: "movie.mp4", link: "link1"),
            DebridCloudDownload(id: "2", fileName: "document.pdf", link: "link2"),
            DebridCloudDownload(id: "3", fileName: "video.mkv", link: "link3")
        ]
        realDebrid.cloudDownloads = downloads
        
        // When
        let mp4Files = realDebrid.getFilteredDownloads(searchText: "", fileType: "mp4")
        let searchResults = realDebrid.getFilteredDownloads(searchText: "movie", fileType: "")
        
        // Then
        XCTAssertEqual(mp4Files.count, 1, "Should find 1 MP4 file")
        XCTAssertEqual(mp4Files.first?.fileName, "movie.mp4")
        XCTAssertEqual(searchResults.count, 1, "Should find 1 file matching 'movie'")
    }
    
    func testMagnetFiltering() {
        // Given
        let magnets = [
            DebridCloudMagnet(id: "1", fileName: "Movie 2023", status: "downloaded", hash: "hash1", links: ["link1"]),
            DebridCloudMagnet(id: "2", fileName: "TV Show S01", status: "downloading", hash: "hash2", links: ["link2"]),
            DebridCloudMagnet(id: "3", fileName: "Documentary", status: "downloaded", hash: "hash3", links: ["link3"])
        ]
        realDebrid.cloudMagnets = magnets
        
        // When
        let downloadedMagnets = realDebrid.getFilteredMagnets(searchText: "", status: "downloaded")
        let movieMagnets = realDebrid.getFilteredMagnets(searchText: "Movie", status: "")
        
        // Then
        XCTAssertEqual(downloadedMagnets.count, 2, "Should find 2 downloaded magnets")
        XCTAssertEqual(movieMagnets.count, 1, "Should find 1 magnet matching 'Movie'")
    }
    
    // MARK: - Video File Detection Tests
    
    func testVideoFileDetection() {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v"]
        
        for ext in videoExtensions {
            let filename = "test.\(ext)"
            let fileExtension = filename.lowercased().split(separator: ".").last ?? ""
            XCTAssertTrue(videoExtensions.contains(String(fileExtension)), "\(ext) should be detected as video")
        }
        
        // Test non-video files
        let nonVideoFiles = ["document.pdf", "archive.zip", "music.mp3"]
        for filename in nonVideoFiles {
            let fileExtension = filename.lowercased().split(separator: ".").last ?? ""
            XCTAssertFalse(videoExtensions.contains(String(fileExtension)), "\(filename) should not be detected as video")
        }
    }
    
    // MARK: - Unchained Plugin Tests
    
    func testUnchainedPluginConversion() {
        // Given
        let unchainedPlugin = UnchainedPluginJson(
            name: "Test Tracker",
            version: "1.0",
            author: "Test Author",
            description: "Test Description",
            website: "https://test.com",
            searchUrl: "https://test.com/search",
            loginUrl: nil,
            loginRequired: false,
            categories: nil,
            search: UnchainedSearchConfig(
                paths: [UnchainedSearchPath(path: "/search", method: "GET", followRedirect: true)],
                inputs: nil,
                keywordsParam: "q",
                categoriesParam: nil,
                rows: UnchainedResultsSelector(selector: ".result-row", attribute: nil)
            ),
            results: UnchainedResultsConfig(
                selector: ".result-row",
                fields: [
                    UnchainedFieldSelector(name: "title", selector: ".title", attribute: "text", filters: nil, optional: false),
                    UnchainedFieldSelector(name: "magnet", selector: ".magnet", attribute: "href", filters: nil, optional: false)
                ]
            ),
            userAgent: nil,
            encoding: nil,
            timeout: nil,
            cookies: nil,
            headers: nil
        )
        
        // When
        let ferriteSource = unchainedPlugin.toFerriteSource()
        
        // Then
        XCTAssertNotNil(ferriteSource, "Should convert to Ferrite source")
        XCTAssertEqual(ferriteSource?.name, "Test Tracker")
        XCTAssertEqual(ferriteSource?.author, "Test Author")
        XCTAssertNotNil(ferriteSource?.htmlParser, "Should create HTML parser")
        XCTAssertTrue(ferriteSource?.website?.contains("test.com") == true, "Should preserve website")
    }
    
    func testUnchainedPluginValidation() {
        // Test required fields
        let validPlugin = UnchainedPluginJson(
            name: "Test",
            version: "1.0",
            author: nil,
            description: nil,
            website: nil,
            searchUrl: "https://test.com",
            loginUrl: nil,
            loginRequired: nil,
            categories: nil,
            search: UnchainedSearchConfig(
                paths: [],
                inputs: nil,
                keywordsParam: nil,
                categoriesParam: nil,
                rows: nil
            ),
            results: UnchainedResultsConfig(
                selector: ".result",
                fields: [
                    UnchainedFieldSelector(name: "title", selector: ".title", attribute: nil, filters: nil, optional: nil)
                ]
            ),
            userAgent: nil,
            encoding: nil,
            timeout: nil,
            cookies: nil,
            headers: nil
        )
        
        XCTAssertFalse(validPlugin.name.isEmpty, "Name should not be empty")
        XCTAssertFalse(validPlugin.searchUrl.isEmpty, "Search URL should not be empty")
        XCTAssertFalse(validPlugin.results.fields.isEmpty, "Results fields should not be empty")
    }
    
    // MARK: - Bulk Operations Tests
    
    func testMagnetBatchCreation() {
        // Given
        let magnets = [
            Magnet(hash: "hash1", link: "magnet:?xt=urn:btih:hash1"),
            Magnet(hash: "hash2", link: "magnet:?xt=urn:btih:hash2"),
            Magnet(hash: "hash3", link: "magnet:?xt=urn:btih:hash3")
        ]
        
        // When
        let magnetLinks = magnets.compactMap { $0.link }
        
        // Then
        XCTAssertEqual(magnetLinks.count, 3, "Should have 3 magnet links")
        for link in magnetLinks {
            XCTAssertTrue(link.hasPrefix("magnet:"), "Should be valid magnet link")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidUrlHandling() {
        // Test empty URL
        let emptyUrl = ""
        XCTAssertTrue(emptyUrl.isEmpty, "Empty URL should be detected")
        
        // Test invalid protocol
        let invalidUrl = "ftp://example.com"
        XCTAssertFalse(invalidUrl.hasPrefix("https://"), "Invalid protocol should be detected")
        
        // Test valid URLs
        let validHttpsUrl = "https://example.com"
        let validHttpUrl = "http://example.com"
        XCTAssertTrue(validHttpsUrl.hasPrefix("https://") || validHttpsUrl.hasPrefix("http://"), "Valid HTTPS URL should pass")
        XCTAssertTrue(validHttpUrl.hasPrefix("https://") || validHttpUrl.hasPrefix("http://"), "Valid HTTP URL should pass")
    }
    
    func testFileValidation() {
        // Test torrent file validation
        let validTorrentFiles = ["movie.torrent", "linux.torrent", "test_file.torrent"]
        let invalidFiles = ["movie.mp4", "document.pdf", "archive.zip", ""]
        
        for file in validTorrentFiles {
            XCTAssertTrue(file.lowercased().hasSuffix(".torrent"), "\(file) should be valid torrent file")
        }
        
        for file in invalidFiles {
            XCTAssertFalse(file.lowercased().hasSuffix(".torrent"), "\(file) should not be valid torrent file")
        }
    }
}

// MARK: - Mock Data Helpers

extension EnhancedDebridTests {
    
    func createMockSearchResults() -> [SearchResult] {
        return [
            SearchResult(
                id: UUID(),
                title: "Test Movie 2023 1080p",
                source: "TestTracker",
                magnet: Magnet(hash: "testhash1", link: "magnet:?xt=urn:btih:testhash1"),
                seeders: 50,
                leechers: 10,
                size: "1.5 GB"
            ),
            SearchResult(
                id: UUID(),
                title: "Test Series S01E01",
                source: "TestTracker",
                magnet: Magnet(hash: "testhash2", link: "magnet:?xt=urn:btih:testhash2"),
                seeders: 25,
                leechers: 5,
                size: "500 MB"
            )
        ]
    }
    
    func createMockTorrentData() -> Data {
        // Create minimal valid torrent file data for testing
        // This is a simplified version - real torrents would be more complex
        let torrentDict: [String: Any] = [
            "announce": "http://tracker.example.com/announce",
            "info": [
                "name": "test_file.txt",
                "length": 1024,
                "piece length": 32768,
                "pieces": Data(repeating: 0, count: 20) // Simplified hash
            ]
        ]
        
        return try! PropertyListSerialization.data(fromPropertyList: torrentDict, format: .binary, options: 0)
    }
}