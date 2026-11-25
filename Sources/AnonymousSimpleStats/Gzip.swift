import Compression
import Foundation

/// `data` in the gzip format (RFC 1952), or nil if compression failed.
/// The Compression framework only makes raw DEFLATE: the header and trailer are added here.
func gzipped(_ data: Data) -> Data? {
    guard !data.isEmpty else { return nil }
    let capacity = data.count + data.count / 2 + 64
    var deflated = Data(count: capacity)
    let size = deflated.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
        data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let out = dst.bindMemory(to: UInt8.self).baseAddress,
                  let input = src.bindMemory(to: UInt8.self).baseAddress
            else { return 0 }
            return compression_encode_buffer(out, capacity, input, data.count, nil, COMPRESSION_ZLIB)
        }
    }
    guard size > 0 else { return nil }

    // ID1 ID2, CM = deflate, no flags, no mtime, no extra flags, OS unknown
    var result = Data([0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0xff])
    result.append(deflated.prefix(size))
    result.appendLittleEndian(crc32(data))
    result.appendLittleEndian(UInt32(truncatingIfNeeded: data.count))
    return result
}

private let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
    var c = UInt32(n)
    for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    return c
}

/// CRC-32 (IEEE 802.3), as gzip needs it.
func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
    return crc ^ 0xFFFF_FFFF
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
