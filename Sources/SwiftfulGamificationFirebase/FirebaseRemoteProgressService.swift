//
//  FirebaseRemoteProgressService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public class FirebaseRemoteProgressService: RemoteProgressService {

    private let rootCollectionName: String
    private var listenerTask: Task<Void, Never>?

    private func userProgressCollection(userId: String, progressKey: String) -> CollectionReference {
        Firestore.firestore().collection(rootCollectionName)
            .document(userId)
            .collection(progressKey)
    }

    /// Initialize the Firebase Remote Progress Service
    /// - Parameter rootCollectionName: The root Firestore collection where all progress data is stored.
    ///   Each user's progress data will be stored under: `{rootCollectionName}/{userId}/{progressKey}/...`
    ///   Example: "swiftful_progress" → "swiftful_progress/user123/general/{progressItemId}"
    public init(rootCollectionName: String) {
        self.rootCollectionName = rootCollectionName
    }

    // MARK: - Progress Items

    public func getAllProgressItems(userId: String, progressKey: String) async throws -> [ProgressItem] {
        try await userProgressCollection(userId: userId, progressKey: progressKey)
            .getAllDocuments()
    }

    public func streamProgressUpdates(userId: String, progressKey: String) -> (
        updates: AsyncThrowingStream<ProgressItem, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        var updatesCont: AsyncThrowingStream<ProgressItem, Error>.Continuation?
        var deletionsCont: AsyncThrowingStream<String, Error>.Continuation?
        
        let updates = AsyncThrowingStream<ProgressItem, Error> { continuation in
            updatesCont = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.listenerTask?.cancel()
                }
            }
        }

        let deletions = AsyncThrowingStream<String, Error> { continuation in
            deletionsCont = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.listenerTask?.cancel()
                }
            }
        }

        // Start the shared Firestore listener
        listenerTask = Task {
            do {
                let collection = userProgressCollection(userId: userId, progressKey: progressKey)
                for try await change in collection.streamAllDocumentChanges() as AsyncThrowingStream<SwiftfulFirestore.DocumentChange<ProgressItem>, Error> {
                    switch change.type {
                    case .added, .modified:
                        updatesCont?.yield(change.document)
                    case .removed:
                        deletionsCont?.yield(change.document.id)
                    }
                }
            } catch {
                updatesCont?.finish(throwing: error)
                deletionsCont?.finish(throwing: error)
            }
        }

        return (updates, deletions)
    }

    public func addProgress(userId: String, progressKey: String, item: ProgressItem) async throws {
        try userProgressCollection(userId: userId, progressKey: progressKey)
            .document(item.id)
            .setData(from: item, merge: true)
    }

    public func deleteProgress(userId: String, progressKey: String, id: String) async throws {
        try await userProgressCollection(userId: userId, progressKey: progressKey)
            .document(id)
            .delete()
    }

    public func deleteAllProgress(userId: String, progressKey: String) async throws {
        try await userProgressCollection(userId: userId, progressKey: progressKey)
            .deleteAllDocuments()
    }
}
