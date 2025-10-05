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

    private var listenerTask: Task<Void, Never>?
    
    private func userProgressCollection(userId: String) -> CollectionReference {
        Firestore.firestore().collection("swiftful_progress")
            .document(userId)
            .collection("items")
    }

    public init() {
    }

    // MARK: - Progress Items

    public func getAllProgressItems(userId: String) async throws -> [ProgressItem] {
        try await userProgressCollection(userId: userId)
            .getAllDocuments()
    }

    public func streamProgressUpdates(userId: String) -> (
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
                let collection = userProgressCollection(userId: userId)
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

    public func updateProgress(userId: String, item: ProgressItem) async throws {
        try userProgressCollection(userId: userId)
            .document(item.id)
            .setData(from: item, merge: true)
    }

    public func deleteProgress(userId: String, id: String) async throws {
        try await userProgressCollection(userId: userId)
            .document(id)
            .delete()
    }

    public func deleteAllProgress(userId: String) async throws {
        try await userProgressCollection(userId: userId)
            .deleteAllDocuments()
    }
}
