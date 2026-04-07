import Foundation
import CloudKit

// MARK: - CloudKit Sharing Service

/// Real-time sharing via CloudKit Public Database.
///
/// Flow:
///   Sender  → uploadSharedList() whenever shared tasks change
///   Recipient → fetchSharedList() on accept; subscribeToChanges() for live updates
///   CloudKit → delivers silent push → app calls refreshReceivedLists() on foreground
final class CloudKitSharingService {

    static let shared = CloudKitSharingService()

    private let container: CKContainer
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    /// CloudKit record type name (must match schema created in CloudKit Dashboard).
    static let recordType = "DPSharedTaskList"

    private init() {
        container = CKContainer(identifier: "iCloud.com.istalin.DailyPlanner")
    }

    // MARK: - Upload / Update

    /// Uploads or updates a shared task list in the CloudKit Public Database.
    /// Called automatically by PlannerViewModel whenever shared tasks change.
    func uploadSharedList(
        shareToken     : String,
        senderName     : String,
        senderEmail    : String,
        recipientEmail : String,
        section        : SharableSection,
        tasks          : [SharedTaskItem],
        completion     : ((Error?) -> Void)? = nil
    ) {
        guard let tasksData = try? JSONEncoder().encode(tasks),
              let tasksJSON = String(data: tasksData, encoding: .utf8) else {
            completion?(CKSharingError.encodingFailed)
            return
        }

        let recordID = CKRecord.ID(recordName: shareToken)

        // Fetch the existing record first so we can update it (avoids server-side conflicts).
        publicDB.fetch(withRecordID: recordID) { [weak self] existing, _ in
            guard let self else { return }
            let record = existing ?? CKRecord(recordType: Self.recordType, recordID: recordID)
            record["senderName"]      = senderName      as CKRecordValue
            record["senderEmail"]     = senderEmail     as CKRecordValue
            record["recipientEmail"]  = recipientEmail  as CKRecordValue
            record["section"]         = section.rawValue as CKRecordValue
            record["tasksJSON"]       = tasksJSON       as CKRecordValue
            record["updatedAt"]       = Date()          as CKRecordValue

            self.publicDB.save(record) { _, error in
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }

    // MARK: - Fetch Single Record

    /// Fetches a single shared task list from CloudKit by share token.
    /// Used when a recipient first accepts a share link.
    func fetchSharedList(
        shareToken : String,
        completion : @escaping (Result<CKSharedListPayload, Error>) -> Void
    ) {
        let recordID = CKRecord.ID(recordName: shareToken)
        publicDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)); return }
                guard let r = record, let payload = CKSharedListPayload(from: r)
                else { completion(.failure(CKSharingError.invalidRecord)); return }
                completion(.success(payload))
            }
        }
    }

    // MARK: - Bulk Refresh

    /// Fetches the latest data for multiple share tokens in one batch operation.
    /// Called when the app comes to foreground to sync all received shared lists.
    func refreshReceivedLists(
        tokens     : [String],
        completion : @escaping ([CKSharedListPayload]) -> Void
    ) {
        guard !tokens.isEmpty else { completion([]); return }

        let recordIDs = tokens.map { CKRecord.ID(recordName: $0) }
        let op = CKFetchRecordsOperation(recordIDs: recordIDs)
        op.desiredKeys = ["senderName", "senderEmail", "recipientEmail", "section", "tasksJSON", "updatedAt"]

        var results: [CKSharedListPayload] = []
        op.perRecordResultBlock = { _, result in
            if case .success(let record) = result,
               let payload = CKSharedListPayload(from: record) {
                results.append(payload)
            }
        }
        op.fetchRecordsResultBlock = { _ in
            DispatchQueue.main.async { completion(results) }
        }
        publicDB.add(op)
    }

    // MARK: - Subscriptions (silent push for live updates)

    /// Creates a CloudKit subscription so this device receives a silent push
    /// whenever the sender updates the shared list.
    func subscribeToChanges(shareToken: String, completion: ((Error?) -> Void)? = nil) {
        let subID = subscriptionID(for: shareToken)

        // Avoid duplicating subscriptions.
        publicDB.fetch(withSubscriptionID: subID) { [weak self] existing, _ in
            guard let self else { return }
            if existing != nil { completion?(nil); return }

            let recordID = CKRecord.ID(recordName: shareToken)
            let pred     = NSPredicate(format: "recordID == %@", recordID)
            let sub      = CKQuerySubscription(
                recordType    : Self.recordType,
                predicate     : pred,
                subscriptionID: subID,
                options       : [.firesOnRecordUpdate]
            )
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true  // silent background push
            sub.notificationInfo = info

            self.publicDB.save(sub) { _, error in
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }

    /// Removes the CloudKit subscription when the recipient removes a shared list.
    func unsubscribe(shareToken: String, completion: ((Error?) -> Void)? = nil) {
        publicDB.delete(withSubscriptionID: subscriptionID(for: shareToken)) { _, error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Delete Record (called when sender stops sharing with a recipient)

    func deleteSharedList(shareToken: String, completion: ((Error?) -> Void)? = nil) {
        let recordID = CKRecord.ID(recordName: shareToken)
        publicDB.delete(withRecordID: recordID) { _, error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Helpers

    private func subscriptionID(for token: String) -> String { "dp-share-\(token)" }

    enum CKSharingError: LocalizedError {
        case encodingFailed, invalidRecord
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode task list for upload."
            case .invalidRecord:  return "The shared list record could not be read."
            }
        }
    }
}

// MARK: - CKSharedListPayload

/// Strongly-typed parsed result of a CloudKit shared list record.
struct CKSharedListPayload {
    var shareToken     : String
    var senderName     : String
    var senderEmail    : String
    var recipientEmail : String
    var section        : SharableSection
    var tasks          : [SharedTaskItem]
    var updatedAt      : Date

    init?(from record: CKRecord) {
        guard let senderName     = record["senderName"]     as? String,
              let senderEmail    = record["senderEmail"]    as? String,
              let recipientEmail = record["recipientEmail"] as? String,
              let sectionRaw     = record["section"]        as? String,
              let section        = SharableSection(rawValue: sectionRaw),
              let tasksJSON      = record["tasksJSON"]      as? String,
              let tasksData      = tasksJSON.data(using: .utf8),
              let tasks          = try? JSONDecoder().decode([SharedTaskItem].self, from: tasksData)
        else { return nil }

        self.shareToken     = record.recordID.recordName
        self.senderName     = senderName
        self.senderEmail    = senderEmail
        self.recipientEmail = recipientEmail
        self.section        = section
        self.tasks          = tasks
        self.updatedAt      = record["updatedAt"] as? Date ?? record.modificationDate ?? Date()
    }
}
