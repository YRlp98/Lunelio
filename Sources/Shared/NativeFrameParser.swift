import Foundation

struct NativeFrameParser {
    private var buffer = Data()
    mutating func append(_ bytes: Data) throws -> [Data] {
        buffer.append(bytes)
        guard buffer.count <= 1_048_580 else { throw CocoaError(.fileReadTooLarge) }
        var frames: [Data] = []
        while buffer.count >= 4 {
            let size = buffer.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
            guard size <= 1_048_576 else { throw CocoaError(.fileReadTooLarge) }
            guard buffer.count >= 4 + Int(size) else { break }
            frames.append(Data(buffer.dropFirst(4).prefix(Int(size))))
            buffer.removeFirst(4 + Int(size))
        }
        return frames
    }
}
