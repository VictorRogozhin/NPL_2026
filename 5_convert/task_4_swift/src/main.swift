import Foundation

struct FormatError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct PPMHeader {
    let bytes: [UInt8]
    var cursor = 0

    static func isSpace(_ byte: UInt8) -> Bool {
        byte == 32 || (9...13).contains(byte)
    }

    mutating func token() throws -> String {
        while cursor < bytes.count {
            if Self.isSpace(bytes[cursor]) {
                cursor += 1
            } else if bytes[cursor] == 35 {
                while cursor < bytes.count && bytes[cursor] != 10 && bytes[cursor] != 13 {
                    cursor += 1
                }
            } else {
                break
            }
        }
        let start = cursor
        while cursor < bytes.count && !Self.isSpace(bytes[cursor]) && bytes[cursor] != 35 {
            cursor += 1
        }
        guard cursor > start, let word = String(bytes: bytes[start..<cursor], encoding: .ascii) else {
            throw FormatError("Missing or invalid PPM header token")
        }
        return word
    }

    mutating func dimension() throws -> Int {
        let word = try token()
        guard word.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(word), value > 0, value <= Int(Int32.max) else {
            throw FormatError("Invalid image dimension")
        }
        return value
    }

    mutating func rasterStart() throws -> Int {
        guard cursor < bytes.count && Self.isSpace(bytes[cursor]) else {
            throw FormatError("Expected whitespace before RGB raster")
        }
        cursor += 1
        return cursor
    }
}

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

func convert(_ source: Data) throws -> (Data, Int, Int) {
    var header = PPMHeader(bytes: Array(source))
    guard try header.token() == "P6" else { throw FormatError("Expected P6 magic") }
    let width = try header.dimension()
    let height = try header.dimension()
    guard try header.token() == "255" else { throw FormatError("Expected maxval 255") }
    let start = try header.rasterStart()

    let rowBytes = width * 3
    let stride = (rowBytes + 3) & ~3
    let (size, overflow) = stride.multipliedReportingOverflow(by: height)
    guard !overflow && size <= Int(UInt32.max) - 54 else {
        throw FormatError("Image exceeds the BMP size limit")
    }
    guard source.count - start == rowBytes * height else {
        throw FormatError("RGB raster size does not match the dimensions")
    }

    var bmp = Data(capacity: 54 + size)
    bmp.append(contentsOf: [0x42, 0x4D])
    bmp.appendLE(UInt32(54 + size))
    bmp.appendLE(UInt32(0))
    bmp.appendLE(UInt32(54))
    bmp.appendLE(UInt32(40))
    bmp.appendLE(Int32(width))
    bmp.appendLE(Int32(height))
    bmp.appendLE(UInt16(1))
    bmp.appendLE(UInt16(24))
    bmp.appendLE(UInt32(0))
    bmp.appendLE(UInt32(size))
    for _ in 0..<4 { bmp.appendLE(UInt32(0)) }

    let padding = [UInt8](repeating: 0, count: stride - rowBytes)
    for y in (0..<height).reversed() {
        let row = start + y * rowBytes
        for x in 0..<width {
            let pixel = row + x * 3
            bmp.append(header.bytes[pixel + 2])
            bmp.append(header.bytes[pixel + 1])
            bmp.append(header.bytes[pixel])
        }
        bmp.append(contentsOf: padding)
    }
    return (bmp, width, height)
}

do {
    let args = CommandLine.arguments
    guard args.count == 3 else { throw FormatError("Usage: converter INPUT.ppm OUTPUT.bmp") }
    let input = try Data(contentsOf: URL(fileURLWithPath: args[1]))
    let (bmp, width, height) = try convert(input)
    try bmp.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
    print("Converted \(width)x\(height) P6 to 24-bit BMP: \(args[2])")
} catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
