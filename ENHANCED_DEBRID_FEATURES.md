# Enhanced Debrid Management Features

This document describes the new enhanced debrid management features added to Ferrite.

## Overview

The enhanced debrid management system significantly expands Ferrite's capabilities for managing Real-Debrid accounts and extends plugin compatibility to support Unchained Android app search plugins.

## New Features

### 1. Web Link Unrestricting

**Purpose**: Convert premium hosting site download links to direct Real-Debrid download links.

**How to Use**:
1. Go to Settings → Enhanced Debrid Management → Unrestrict Web Links
2. Paste a download link from a supported hosting site
3. Tap "Unrestrict Link" to convert it to a Real-Debrid download

**Supported Hosts**: The app automatically checks which hosts are supported by your Real-Debrid account. Common hosts include:
- rapidgator.net
- uploaded.net  
- nitroflare.com
- turbobit.net
- 1fichier.com
- mediafire.com

### 2. Torrent File Upload

**Purpose**: Upload .torrent files directly from your device to your Real-Debrid account.

**How to Use**:
1. Go to Settings → Enhanced Debrid Management → Upload Torrent Files
2. Tap "Select Torrent Files" to browse your device
3. Select one or more .torrent files (max 1MB each)
4. Tap "Upload" to add them to your Real-Debrid account

**Requirements**:
- Files must be in .torrent format
- Maximum file size: 1MB per file
- Valid torrent files only

### 3. Enhanced Cloud Management

**Purpose**: Better organization and management of your Real-Debrid cloud files.

**New Features**:
- **File Type Filtering**: Filter downloads by file extension (mp4, mkv, avi, etc.)
- **Status Filtering**: Filter magnets by status (downloaded, downloading, queued, error)
- **Transcoding URLs**: Generate transcoding links for video files
- **Quick Actions**: Easy access to upload and unrestrict functions

**How to Use**:
1. Go to Library → Debrid Cloud
2. Use the filter menus at the top to organize your files
3. For video files, tap the TV icon to get transcoding URLs
4. Use the "+" menu to access upload and unrestrict features

### 4. Bulk Download Management

**Purpose**: Add multiple search results to your Real-Debrid download queue at once.

**How to Use**:
1. Search for content as usual
2. Long-press any search result to access the context menu
3. Select "Add to Download Queue" for individual items
4. Or go to Settings → Enhanced Debrid Management → Bulk Downloads for batch operations

**Features**:
- Select multiple search results
- Batch add to Real-Debrid queue
- Progress tracking for bulk operations

### 5. Transcoding URL Generation

**Purpose**: Generate optimized streaming URLs for different platforms.

**How to Use**:
1. Go to Library → Debrid Cloud
2. Find a video file in your downloads
3. Tap the TV icon next to the file
4. Choose your platform (Apple, Android, Chrome)
5. The transcoded URL will be added to your history and opened with your default action

**Supported Formats**:
- Apple: Optimized for iOS/macOS devices
- Android: Optimized for Android devices  
- Chrome: Optimized for web browsers

### 6. Unchained Plugin Compatibility

**Purpose**: Import and use search plugins from the Unchained Android debrid management app.

**Why Use Unchained Plugins**: Unchained plugins often perform much better than native Ferrite plugins because they:
- Have been extensively tested by the Unchained community
- Include optimized search parameters
- Support more trackers and indexers
- Receive regular updates

**How to Use**:
1. Go to Settings → Plugin Management → Unchained Plugins
2. Enter the URL of an Unchained plugin JSON file
3. Tap "Import Plugin" to convert and install it
4. The plugin will appear in your regular plugin list

**Plugin Format**: Unchained plugins are automatically converted to Ferrite's format, supporting:
- Custom search URLs and parameters
- HTML parsing with CSS selectors
- Field extraction for titles, sizes, seeders, etc.
- Custom headers and request configurations

## API Enhancements

### New Real-Debrid Endpoints

The following new API endpoints have been added to the Real-Debrid integration:

- `uploadTorrentFile()`: Upload .torrent files
- `unrestrictWebLink()`: Unrestrict premium hosting links
- `getTranscodingUrl()`: Generate transcoding URLs
- `getSupportedHosts()`: Get list of supported hosts
- `addMagnets()`: Batch add multiple magnets
- `getFilteredDownloads()`: Enhanced filtering for downloads
- `getFilteredMagnets()`: Enhanced filtering for magnets

### Error Handling

Enhanced error handling provides better user feedback for:
- Network connectivity issues
- Invalid file formats
- Unsupported hosting sites
- Real-Debrid API errors
- Plugin conversion failures

## Settings Integration

All new features are accessible through the Settings app:

**Enhanced Debrid Management Section**:
- Unrestrict Web Links
- Upload Torrent Files  
- Bulk Downloads

**Plugin Management Section**:
- Unchained Plugins (new)
- Plugin Lists (existing)

## Compatibility

- **iOS Version**: Requires iOS 16+ (same as existing Ferrite requirements)
- **Real-Debrid Account**: Required for all debrid management features
- **File Formats**: Supports standard torrent and magnet link formats
- **Plugin Compatibility**: Backwards compatible with existing Ferrite plugins

## Usage Tips

1. **Check Host Support**: Before trying to unrestrict a link, check if the host is supported by viewing the supported hosts list
2. **Batch Operations**: Use bulk downloads for multiple items to save time
3. **Transcoding**: Use transcoding URLs for better streaming performance on mobile devices
4. **Plugin Sources**: Look for Unchained plugin repositories online for the best selection
5. **File Management**: Use filters in cloud management to quickly find specific types of content

## Troubleshooting

**Web Link Unrestricting Issues**:
- Ensure the link is from a supported hosting site
- Check your Real-Debrid account has premium access
- Verify the link is valid and not expired

**Torrent Upload Issues**:
- Ensure files are in .torrent format
- Check file size is under 1MB
- Verify torrent files are not corrupted

**Plugin Import Issues**:
- Ensure the URL points to a valid Unchained plugin JSON file
- Check your internet connection
- Verify the plugin format is compatible

**Transcoding Issues**:
- Ensure the file is a video format
- Check your Real-Debrid account supports transcoding
- Try different transcoding formats if one doesn't work

For additional support, check the Ferrite Discord server or GitHub repository.