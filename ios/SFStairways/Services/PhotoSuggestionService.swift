import Foundation
import Photos

@Observable
@MainActor
final class PhotoSuggestionService {
    private(set) var suggestions: [PHAsset] = []

    func fetch(
        dateWalked: Date,
        walkStartTime: Date? = nil,
        walkEndTime: Date? = nil,
        addedPhotoAssetIDs: [String],
        dismissedPhotoIDs: [String]
    ) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            suggestions = []
            return
        }

        let (start, end) = timeWindow(dateWalked: dateWalked, startTime: walkStartTime, endTime: walkEndTime)

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate,
            end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let excluded = Set(addedPhotoAssetIDs + dismissedPhotoIDs)
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if !excluded.contains(asset.localIdentifier) {
                assets.append(asset)
            }
        }
        suggestions = assets
    }

    func loadFullImage(asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func timeWindow(dateWalked: Date, startTime: Date?, endTime: Date?) -> (Date, Date) {
        if let start = startTime, let end = endTime {
            return (start, end)
        }
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let dayStart = cal.startOfDay(for: dateWalked)
        let dayEnd = cal.date(byAdding: .init(day: 1, second: -1), to: dayStart) ?? dayStart
        return (dayStart, dayEnd)
    }
}
