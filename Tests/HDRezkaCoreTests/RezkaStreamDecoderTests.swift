import XCTest
@testable import HDRezkaCore

final class RezkaStreamDecoderTests: XCTestCase {
    
    func testCleanStreamParsing() {
        let streamString = "[360p]https://stream.host/360.mp4 or https://stream.host/360.m3u8:hls:manifest.m3u8,[720p]https://stream.host/720.mp4,[1080p Ultra]https://stream.host/1080.mp4"
        let streams = RezkaStreamDecoder.parseStreams(from: streamString)
        
        XCTAssertEqual(streams.count, 3)
        XCTAssertEqual(streams[0].quality, .res1080pUltra)
        XCTAssertEqual(streams[1].quality, .res720p)
        XCTAssertEqual(streams[2].quality, .res360p)
        XCTAssertTrue(streams[2].isHLS)
    }
    
    func testSubtitleParsing() {
        let rawSubs = "[Русский]https://subs.host/ru.vtt,[English]https://subs.host/en.vtt"
        let codes = ["Русский": "ru", "English": "en"]
        let subs = RezkaStreamDecoder.parseSubtitles(rawSubtitleString: rawSubs, codes: codes)
        
        XCTAssertEqual(subs.count, 2)
        XCTAssertEqual(subs[0].code, "ru")
        XCTAssertEqual(subs[0].language, "Русский")
        XCTAssertEqual(subs[0].url.absoluteString, "https://subs.host/ru.vtt")
        XCTAssertEqual(subs[1].code, "en")
    }
    
    func testObfuscatedStreamDecryption() {
        let originalPayload = "[720p]https://cdn.example.com/stream/720.mp4,[1080p]https://cdn.example.com/stream/1080.mp4"
        let base64Original = originalPayload.data(using: .utf8)!.base64EncodedString()
        
        // Inject trash code like base64("@#") which is "@#" in base64 = "QCM="
        let trashToken = "@#".data(using: .utf8)!.base64EncodedString()
        let obfuscated = "#h" + String(base64Original.prefix(10)) + "//_//" + trashToken + String(base64Original.dropFirst(10))
        
        let decoded = RezkaStreamDecoder.decodeStreamPayload(obfuscated)
        XCTAssertEqual(decoded, originalPayload)
    }
}
