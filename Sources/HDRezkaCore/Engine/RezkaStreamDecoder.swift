import Foundation

public enum RezkaStreamDecoder {
    
    /// Precomputed trash tokens set for HDRezka's stream URL deobfuscation
    private static let trashList = ["@", "#", "!", "^", "$"]
    
    private static let trashCodesSet: [String] = {
        var codes: [String] = []
        // Permutations of length 2 and 3
        for char1 in trashList {
            for char2 in trashList {
                let combo2 = "\(char1)\(char2)"
                if let data = combo2.data(using: .utf8) {
                    codes.append(data.base64EncodedString())
                }
                for char3 in trashList {
                    let combo3 = "\(char1)\(char2)\(char3)"
                    if let data = combo3.data(using: .utf8) {
                        codes.append(data.base64EncodedString())
                    }
                }
            }
        }
        return codes
    }()
    
    /// Decodes HDRezka obfuscated stream URL payload (starts with "#h" and base64 with trash strings)
    public static func decodeStreamPayload(_ rawPayload: String) -> String {
        var cleaned = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#h") {
            cleaned = String(cleaned.dropFirst(2))
        }
        
        // Split by '//_//' separator and recombine
        let segments = cleaned.components(separatedBy: "//_//")
        var trashString = segments.joined()
        
        // Remove all known base64 trash codes
        for trashCode in trashCodesSet {
            trashString = trashString.replacingOccurrences(of: trashCode, with: "")
        }
        
        // Ensure base64 padding
        let remainder = trashString.count % 4
        if remainder > 0 {
            trashString += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let decodedData = Data(base64Encoded: trashString),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            // Fallback: if already raw clear text
            return rawPayload
        }
        
        return decodedString
    }
    
    /// Parses decoded stream strings into structured `StreamOption` array
    /// Format: "[360p]https://stream.../360.mp4 or https://stream.../360.m3u8:hls:manifest.m3u8,[720p]..."
    public static func parseStreams(from decodedString: String) -> [StreamOption] {
        var streams: [StreamOption] = []
        let rawEntries = decodedString.components(separatedBy: ",")
        
        for entry in rawEntries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("["), let closingBracket = trimmed.firstIndex(of: "]") else {
                continue
            }
            
            let qualityLabel = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
            let urlsPart = String(trimmed[trimmed.index(after: closingBracket)...])
            
            let urlCandidates = urlsPart.components(separatedBy: " or ")
            
            // Prefer HLS .m3u8 manifest if available for smooth adaptive streaming, else MP4
            var targetURLString = urlCandidates.first ?? urlsPart
            var isHLS = false
            
            for candidate in urlCandidates {
                let cleanCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanCandidate.contains(".m3u8") || cleanCandidate.contains(":hls:manifest.m3u8") {
                    targetURLString = cleanCandidate.replacingOccurrences(of: ":hls:manifest.m3u8", with: "")
                    isHLS = true
                    break
                }
            }
            
            if !isHLS {
                // If MP4 candidate is available
                targetURLString = urlCandidates.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            
            if let streamURL = URL(string: targetURLString) {
                let quality = VideoQuality.from(raw: qualityLabel)
                streams.append(StreamOption(
                    quality: quality,
                    rawResolutionLabel: qualityLabel,
                    url: streamURL,
                    isHLS: isHLS
                ))
            }
        }
        
        // Sort streams descending by quality (4K, 1080p, 720p...)
        return streams.sorted(by: { $0.quality > $1.quality })
    }
    
    /// Parses subtitle payload and language codes
    /// Subtitles format: "[Русский]https://.../ru.vtt,[English]https://.../en.vtt"
    /// Codes dictionary: ["Русский": "ru", "English": "en"]
    public static func parseSubtitles(
        rawSubtitleString: String?,
        codes: [String: String] = [:]
    ) -> [SubtitleTrack] {
        guard let raw = rawSubtitleString, !raw.isEmpty else { return [] }
        
        var tracks: [SubtitleTrack] = []
        let entries = raw.components(separatedBy: ",")
        
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("["), let closingBracket = trimmed.firstIndex(of: "]") else {
                continue
            }
            
            let language = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
            let urlString = String(trimmed[trimmed.index(after: closingBracket)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let subURL = URL(string: urlString) {
                let code = codes[language] ?? language.lowercased().prefix(2).description
                tracks.append(SubtitleTrack(code: code, language: language, url: subURL))
            }
        }
        
        return tracks
    }
}
