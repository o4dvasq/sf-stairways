import Foundation
import CoreData

// Listens to NSPersistentCloudKitContainer event notifications, which SwiftData
// still posts internally when CloudKit sync is active.
@Observable
final class SyncStatusManager {
    enum SyncState {
        case unknown
        case syncing
        case synced(Date)
        case unavailable(String) // CloudKit container failed to initialize
        case error(String)       // Sync event reported an error
    }

    var state: SyncState = .unknown
    private var eventObserver: NSObjectProtocol?

    init() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
    }

    deinit {
        if let observer = eventObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func markUnavailable(reason: String) {
        state = .unavailable(reason)
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }

        if event.endDate == nil {
            state = .syncing
        } else if event.succeeded {
            state = .synced(event.endDate ?? Date())
        } else if let error = event.error {
            state = .error(error.localizedDescription)
        }
    }
}
