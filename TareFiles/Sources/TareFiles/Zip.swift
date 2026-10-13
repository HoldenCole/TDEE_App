import Foundation
import ZIPFoundation

/// In-memory zip packing and unpacking on top of ZIPFoundation.
enum Zip {

    /// Builds a deflated zip archive from (path, data) pairs, in order.
    static func archive(_ files: [(String, Data)]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for (path, data) in files {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count),
                                 compressionMethod: .deflate) { position, size in
                let start = Int(position)
                return data.subdata(in: start..<min(start + size, data.count))
            }
        }
        guard let out = archive.data else { throw XLSXError.notAZipArchive }
        return out
    }

    /// Extracts every file entry into a path → data map. Paths are normalized to forward
    /// slashes without a leading slash.
    static func unarchive(_ data: Data) throws -> [String: Data] {
        let archive = try Archive(data: data, accessMode: .read)
        var out: [String: Data] = [:]
        for entry in archive where entry.type == .file {
            var collected = Data()
            _ = try archive.extract(entry, skipCRC32: true) { chunk in collected.append(chunk) }
            var path = entry.path.replacingOccurrences(of: "\\", with: "/")
            while path.hasPrefix("/") { path.removeFirst() }
            out[path] = collected
        }
        return out
    }
}
