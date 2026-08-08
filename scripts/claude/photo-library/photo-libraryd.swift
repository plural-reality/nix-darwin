import AppKit
import CryptoKit
import Foundation
import Photos
import Vision

struct BridgeRequest: Decodable {
    let op: String
    let spec: RequestSpec?
}

struct RequestSpec: Decodable {
    let assetIds: [String]?
    let runId: String?
}

struct AssetRecord: Encodable {
    let id: String
    let creationDate: String?
    let modificationDate: String?
    let pixelWidth: Int
    let pixelHeight: Int
}

struct CardSignals: Encodable, Equatable {
    let lineCount: Int
    let hasRectangle: Bool
    let hasEmail: Bool
    let hasPhone: Bool
    let hasURL: Bool
    let hasOrganization: Bool
    let score: Double
    let candidate: Bool
}

struct ClassificationRecord: Encodable {
    let id: String
    let signals: CardSignals
}

struct ExportRecord: Encodable {
    let id: String
    let path: String
    let sha256: String
}

struct BridgeOutput: Encodable {
    let type: String
    let authorization: String?
    let asset: AssetRecord?
    let classification: ClassificationRecord?
    let export: ExportRecord?
    let ok: Bool?
    let count: Int?
    let error: String?

    static let authorization: (String) -> BridgeOutput = {
        BridgeOutput(
            type: "authorization", authorization: $0, asset: nil,
            classification: nil, export: nil, ok: nil, count: nil, error: nil)
    }

    static let asset: (AssetRecord) -> BridgeOutput = {
        BridgeOutput(
            type: "asset", authorization: nil, asset: $0,
            classification: nil, export: nil, ok: nil, count: nil, error: nil)
    }

    static let classification: (ClassificationRecord) -> BridgeOutput = {
        BridgeOutput(
            type: "classification", authorization: nil, asset: nil,
            classification: $0, export: nil, ok: nil, count: nil, error: nil)
    }

    static let export: (ExportRecord) -> BridgeOutput = {
        BridgeOutput(
            type: "export", authorization: nil, asset: nil,
            classification: nil, export: $0, ok: nil, count: nil, error: nil)
    }

    static let success: (Int) -> BridgeOutput = {
        BridgeOutput(
            type: "end", authorization: nil, asset: nil,
            classification: nil, export: nil, ok: true, count: $0, error: nil)
    }

    static let failure: (String) -> BridgeOutput = {
        BridgeOutput(
            type: "end", authorization: nil, asset: nil,
            classification: nil, export: nil, ok: false, count: 0, error: $0)
    }
}

enum BridgeFailure: LocalizedError {
    case invalid(String)
    case authorization(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .authorization(message), let .unavailable(message):
            message
        }
    }
}

private let iso8601 = ISO8601DateFormatter()

let authorizationName: (PHAuthorizationStatus) -> String = {
    switch $0 {
    case .notDetermined: "not_determined"
    case .restricted: "restricted"
    case .denied: "denied"
    case .authorized: "authorized"
    case .limited: "limited"
    @unknown default: "unknown"
    }
}

let requireFullAuthorization: () throws -> Void = {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard status == .authorized else {
        throw BridgeFailure.authorization("Photos Full Access required; current status: \(authorizationName(status))")
    }
}

let requestFullAuthorization: () -> PHAuthorizationStatus = {
    let semaphore = DispatchSemaphore(value: 0)
    let lock = NSLock()
    var result = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        lock.lock()
        result = status
        lock.unlock()
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 300)
    lock.lock()
    defer { lock.unlock() }
    return result
}

let allAssets: () -> [PHAsset] = {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    let result = PHAsset.fetchAssets(with: options)
    return (0..<result.count).map { result.object(at: $0) }
}

let assetsByID: ([String]) -> [PHAsset] = { identifiers in
    let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
    let byID = Dictionary(uniqueKeysWithValues: (0..<result.count).map {
        let asset = result.object(at: $0)
        return (asset.localIdentifier, asset)
    })
    return identifiers.compactMap { byID[$0] }
}

let assetRecord: (PHAsset) -> AssetRecord = {
    AssetRecord(
        id: $0.localIdentifier,
        creationDate: $0.creationDate.map(iso8601.string(from:)),
        modificationDate: $0.modificationDate.map(iso8601.string(from:)),
        pixelWidth: $0.pixelWidth,
        pixelHeight: $0.pixelHeight)
}

let requestedImage: (PHAsset, CGFloat) -> NSImage? = { asset, maximumDimension in
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.isNetworkAccessAllowed = true
    options.isSynchronous = true
    var output: NSImage?
    PHImageManager.default().requestImage(
        for: asset,
        targetSize: NSSize(width: maximumDimension, height: maximumDimension),
        contentMode: .aspectFit,
        options: options
    ) { image, info in
        let degraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
        output = degraded ? output : image
    }
    return output
}

let cgImage: (NSImage) -> CGImage? = { image in
    var proposedRect = NSRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
}

let containsPattern: (String, String) -> Bool = { text, pattern in
    text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

let evaluateCardCandidate: ([String], Bool) -> CardSignals = { texts, hasRectangle in
    let joined = texts.joined(separator: "\n")
    let hasEmail = containsPattern(joined, #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#)
    let hasPhone = containsPattern(joined, #"(?:\+?\d[\d() -]{7,}\d)"#)
    let hasURL = containsPattern(joined, #"(?:https?://|www\.|[A-Z0-9-]+\.(?:com|org|net|jp|co\.jp))"#)
    let hasOrganization = containsPattern(
        joined,
        #"(?:株式会社|有限会社|一般社団法人|合同会社|大学|区役所|市役所|代表|取締役|部長|課長|CEO|Founder|Director|Inc\.|Ltd\.)"#)
    let contactCount = [hasEmail, hasPhone, hasURL].filter { $0 }.count
    let score = min(
        1.0,
        (hasRectangle ? 0.35 : 0.0)
            + (texts.count >= 3 ? 0.20 : 0.0)
            + (hasEmail ? 0.20 : 0.0)
            + (hasPhone ? 0.10 : 0.0)
            + (hasURL ? 0.10 : 0.0)
            + (hasOrganization ? 0.15 : 0.0))
    return CardSignals(
        lineCount: texts.count,
        hasRectangle: hasRectangle,
        hasEmail: hasEmail,
        hasPhone: hasPhone,
        hasURL: hasURL,
        hasOrganization: hasOrganization,
        score: score,
        candidate: texts.count >= 3 && (
            (hasRectangle && (contactCount >= 2 || (contactCount >= 1 && hasOrganization)))
                || (hasEmail && hasPhone && hasOrganization)))
}

let classify: (PHAsset) throws -> ClassificationRecord = { asset in
    guard let image = requestedImage(asset, 1600), let pixels = cgImage(image) else {
        throw BridgeFailure.unavailable("image unavailable for asset \(asset.localIdentifier)")
    }
    let textRequest = VNRecognizeTextRequest()
    textRequest.recognitionLevel = .accurate
    textRequest.recognitionLanguages = ["ja-JP", "en-US"]
    textRequest.usesLanguageCorrection = true

    let rectangleRequest = VNDetectRectanglesRequest()
    rectangleRequest.maximumObservations = 5
    rectangleRequest.minimumConfidence = 0.45
    rectangleRequest.minimumAspectRatio = 0.45
    rectangleRequest.maximumAspectRatio = 0.78
    rectangleRequest.minimumSize = 0.20
    rectangleRequest.quadratureTolerance = 25

    try VNImageRequestHandler(cgImage: pixels, options: [:]).perform([textRequest, rectangleRequest])
    let texts = (textRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    let hasRectangle = !(rectangleRequest.results ?? []).isEmpty
    return ClassificationRecord(
        id: asset.localIdentifier,
        signals: evaluateCardCandidate(texts, hasRectangle))
}

let validRunID: (String) -> Bool = {
    $0.range(of: #"\A[A-Za-z0-9._-]{1,80}\z"#, options: .regularExpression) != nil
}

let sha256: (Data) -> String = {
    SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
}

let jpegData: (PHAsset) throws -> Data = { asset in
    guard let image = requestedImage(asset, 3000), let pixels = cgImage(image) else {
        throw BridgeFailure.unavailable("image unavailable for asset \(asset.localIdentifier)")
    }
    guard let data = NSBitmapImageRep(cgImage: pixels).representation(
        using: .jpeg,
        properties: [.compressionFactor: 0.92]
    ) else {
        throw BridgeFailure.unavailable("JPEG conversion failed for asset \(asset.localIdentifier)")
    }
    return data
}

let exportRoot: () -> URL = {
    let configured = ProcessInfo.processInfo.environment["PHOTO_LIBRARY_EXPORT_ROOT"]
    let path = configured ?? NSHomeDirectory() + "/Library/Application Support/PhotoLibraryBridge/exports"
    return URL(fileURLWithPath: path, isDirectory: true)
}

let exportAsset: (PHAsset, String) throws -> ExportRecord = { asset, runID in
    guard validRunID(runID) else {
        throw BridgeFailure.invalid("runId must match [A-Za-z0-9._-]{1,80}")
    }
    let directory = exportRoot().appendingPathComponent(runID, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    let data = try jpegData(asset)
    let digest = sha256(data)
    let destination = directory.appendingPathComponent(String(digest.prefix(24)) + ".jpg")
    try data.write(to: destination, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    return ExportRecord(id: asset.localIdentifier, path: destination.path, sha256: digest)
}

let boundedAssetIDs: (RequestSpec?) throws -> [String] = { spec in
    let identifiers = spec?.assetIds ?? []
    guard !identifiers.isEmpty && identifiers.count <= 100 else {
        throw BridgeFailure.invalid("assetIds count must be between 1 and 100")
    }
    return identifiers
}

let execute: (BridgeRequest) throws -> [BridgeOutput] = { request in
    switch request.op {
    case "status":
        let value = authorizationName(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        return [.authorization(value), .success(1)]
    case "requestAuthorization":
        let value = authorizationName(requestFullAuthorization())
        return [.authorization(value), .success(1)]
    case "snapshot":
        try requireFullAuthorization()
        let records = allAssets().map(assetRecord).sorted { $0.id < $1.id }
        return records.map(BridgeOutput.asset) + [.success(records.count)]
    case "classify":
        try requireFullAuthorization()
        let identifiers = try boundedAssetIDs(request.spec)
        let records = try assetsByID(identifiers).map(classify)
        return records.map(BridgeOutput.classification) + [.success(records.count)]
    case "export":
        try requireFullAuthorization()
        let identifiers = try boundedAssetIDs(request.spec)
        guard let runID = request.spec?.runId else {
            throw BridgeFailure.invalid("runId is required")
        }
        let records = try assetsByID(identifiers).map { try exportAsset($0, runID) }
        return records.map(BridgeOutput.export) + [.success(records.count)]
    default:
        throw BridgeFailure.invalid("unsupported operation: \(request.op)")
    }
}

let encodedLines: ([BridgeOutput]) throws -> Data = { outputs in
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try outputs.map { try encoder.encode($0) + Data([0x0A]) }.reduce(Data(), +)
}

let runBridge: () -> Int32 = {
    do {
        guard let line = readLine(), line.utf8.count <= 16_384 else {
            throw BridgeFailure.invalid("request must be one JSON line no larger than 16 KiB")
        }
        let request = try JSONDecoder().decode(BridgeRequest.self, from: Data(line.utf8))
        try FileHandle.standardOutput.write(contentsOf: encodedLines(try execute(request)))
        return 0
    } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        try? FileHandle.standardOutput.write(contentsOf: try encodedLines([.failure(message)]))
        return 1
    }
}

let runAuthorizationUI: () -> Int32 = {
    _ = NSApplication.shared.setActivationPolicy(.accessory)
    let runLoop = CFRunLoopGetCurrent()
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        NSLog("PhotoLibraryBridge authorization result: %@", authorizationName(status))
        CFRunLoopStop(runLoop)
    }
    CFRunLoopRun()
    return PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ? 0 : 77
}

#if !PHOTO_LIBRARY_TESTING
@main
enum PhotoLibraryBridge {
    static func main() {
        let mode = CommandLine.arguments.dropFirst().first
        exit(mode == "--authorize-ui" ? runAuthorizationUI() : runBridge())
    }
}
#endif
