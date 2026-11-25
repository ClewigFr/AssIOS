import Compression
import Foundation
import Testing
@testable import AnonymousSimpleStats

struct GzipTests {
    @Test func crcMatchesTheStandardCheckValue() {
        #expect(crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test func producesAGzipStreamThatInflatesBack() throws {
        let input = Data(String(repeating: "{\"page\":\"30269ec7-8441-4493-ad65-8b3a7976c8c4\"},", count: 50).utf8)
        let output = try #require(gzipped(input))
        #expect(Array(output.prefix(3)) == [0x1f, 0x8b, 0x08])
        #expect(output.count < input.count)

        let trailer = Array(output.suffix(8))
        let crc = trailer[0..<4].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        let size = trailer[4..<8].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        #expect(crc == crc32(input))
        #expect(size == UInt32(input.count))

        let deflated = Data(output.dropFirst(10).dropLast(8))
        var inflated = Data(count: input.count * 2)
        let inflatedSize = inflated.withUnsafeMutableBytes { dst in
            deflated.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, input.count * 2,
                                          src.bindMemory(to: UInt8.self).baseAddress!, deflated.count, nil, COMPRESSION_ZLIB)
            }
        }
        #expect(inflated.prefix(inflatedSize) == input)
    }

    @Test func emptyInputIsNotCompressed() {
        #expect(gzipped(Data()) == nil)
    }
}
