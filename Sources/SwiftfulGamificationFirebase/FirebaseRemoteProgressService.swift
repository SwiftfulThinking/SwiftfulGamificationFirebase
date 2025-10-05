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
public struct FirebaseRemoteProgressService: RemoteProgressService {

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

    public func streamProgressUpdates(userId: String) -> AsyncThrowingStream<ProgressItem, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                for try await items in userProgressCollection(userId: userId).streamAllDocuments() {
                    for item in items {
                        continuation.yield(item)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
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
