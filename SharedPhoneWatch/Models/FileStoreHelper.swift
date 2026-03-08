//
//  FileStoreHelper.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.03.26.
//

import Foundation

enum FileStorePersistenceError: LocalizedError {
    case failedToReadData(URL, Error)
    case failedToDecodeSnapshot(URL, Error)
    case failedToEncodeSnapshot(Error)
    case failedToCreateDirectory(URL, Error)
    case failedToWriteSnapshot(URL, Error)

    var errorDescription: String? {
        switch self {
        case let .failedToReadData(url, error):
            "Failed to read store snapshot data at \(url.path): \(error.localizedDescription)"
        case let .failedToDecodeSnapshot(url, error):
            "Failed to decode store snapshot at \(url.path): \(error.localizedDescription)"
        case let .failedToEncodeSnapshot(error):
            "Failed to encode store snapshot: \(error.localizedDescription)"
        case let .failedToCreateDirectory(url, error):
            "Failed to create store directory \(url.path): \(error.localizedDescription)"
        case let .failedToWriteSnapshot(url, error):
            "Failed to write store snapshot at \(url.path): \(error.localizedDescription)"
        }
    }
}

enum FileStoreIO {
    static func makeStoreURL(fileName: String, using fileManager: FileManager, appGroupID: String?) -> URL {
        let directoryURL: URL
        if let appGroupID,
           let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            directoryURL = containerURL.appendingPathComponent("Stores", isDirectory: true)
        } else {
            let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            directoryURL = fallback.appendingPathComponent("Stores", isDirectory: true)
        }
        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func readSnapshot<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        using decoder: JSONDecoder,
        fileManager: FileManager
    ) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileStorePersistenceError.failedToReadData(url, error)
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw FileStorePersistenceError.failedToDecodeSnapshot(url, error)
        }
    }

    static func writeSnapshot<T: Encodable>(
        _ snapshot: T,
        to url: URL,
        using encoder: JSONEncoder,
        fileManager: FileManager
    ) throws -> Date {
        let data: Data
        do {
            data = try encoder.encode(snapshot)
        } catch {
            throw FileStorePersistenceError.failedToEncodeSnapshot(error)
        }

        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw FileStorePersistenceError.failedToCreateDirectory(url.deletingLastPathComponent(), error)
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw FileStorePersistenceError.failedToWriteSnapshot(url, error)
        }

        return modificationDate(at: url, fileManager: fileManager) ?? Date()
    }

    static func modificationDate(at url: URL, fileManager: FileManager) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.modificationDate] as? Date
    }
}
