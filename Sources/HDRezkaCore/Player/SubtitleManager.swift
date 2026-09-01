import Foundation

public struct SubtitleCue: Identifiable, Sendable {
    public var id: String { "\(startTime)-\(endTime)-\(text)" }
    public let startTime: Double
    public let endTime: Double
    public let text: String
    
    public init(startTime: Double, endTime: Double, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public actor SubtitleManager {
    public static let shared = SubtitleManager()
    
    private var cues: [SubtitleCue] = []
    private var currentTrack: SubtitleTrack?
    
    public init() {}
    
    public func loadSubtitles(from track: SubtitleTrack) async -> Bool {
        self.currentTrack = track
        self.cues = []
        
        do {
            let (data, _) = try await URLSession.shared.data(from: track.url)
            guard let content = String(data: data, encoding: .utf8) else {
                return false
            }
            self.cues = parseWebVTTorSRT(content)
            return !cues.isEmpty
        } catch {
            return false
        }
    }
    
    public func clearSubtitles() {
        self.cues = []
        self.currentTrack = nil
    }
    
    public func getCue(at timeSeconds: Double) -> String? {
        guard let cue = cues.first(where: { timeSeconds >= $0.startTime && timeSeconds <= $0.endTime }) else {
            return nil
        }
        return cue.text
    }
    
    private func parseWebVTTorSRT(_ rawText: String) -> [SubtitleCue] {
        var parsedCues: [SubtitleCue] = []
        let lines = rawText.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for timestamp line (e.g. 00:01:20.000 --> 00:01:23.000 or 00:01:20,000 --> 00:01:23,000)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count == 2 {
                    let startStr = parts[0].trimmingCharacters(in: .whitespaces)
                    let endStr = parts[1].components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    
                    if let start = parseTimestamp(startStr), let end = parseTimestamp(endStr) {
                        var textLines: [String] = []
                        i += 1
                        while i < lines.count && !lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let textLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                            // Strip basic HTML/VTT tags
                            let cleanText = textLine.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            textLines.append(cleanText)
                            i += 1
                        }
                        
                        let text = textLines.joined(separator: "\n")
                        if !text.isEmpty {
                            parsedCues.append(SubtitleCue(startTime: start, endTime: end, text: text))
                        }
                    }
                }
            }
            i += 1
        }
        
        return parsedCues.sorted(by: { $0.startTime < $1.startTime })
    }
    
    private func parseTimestamp(_ timestampStr: String) -> Double? {
        let clean = timestampStr.replacingOccurrences(of: ",", with: ".")
        let components = clean.components(separatedBy: ":")
        
        guard components.count >= 2 else { return nil }
        
        if components.count == 3 {
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else { return nil }
            return (hours * 3600) + (minutes * 60) + seconds
        } else if components.count == 2 {
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else { return nil }
            return (minutes * 60) + seconds
        }
        return nil
    }
}
