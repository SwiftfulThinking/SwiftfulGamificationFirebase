//
//  FirebaseRemoteStreakService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteStreakService: RemoteStreakService {

    private func userStreakCollection(userId: String, streakKey: String) -> CollectionReference {
        Firestore.firestore().collection("swiftful_streaks")
            .document(userId)
            .collection(streakKey)
    }

    private func currentStreakDoc(userId: String, streakKey: String) -> DocumentReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("current_streak")
    }

    private func eventsCollection(userId: String, streakKey: String) -> CollectionReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("streak_events")
            .collection("data")
    }

    private func freezesCollection(userId: String, streakKey: String) -> CollectionReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("streak_freezes")
            .collection("data")
    }

    public init() {
    }

    // MARK: - Current Streak

    public func streamCurrentStreak(userId: String, streakKey: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .streamDocument(id: "current_streak")
    }

    public func updateCurrentStreak(userId: String, streakKey: String, streak: CurrentStreakData) async throws {
        try currentStreakDoc(userId: userId, streakKey: streakKey).setData(from: streak, merge: true)
    }

    public func calculateStreak(userId: String, streakKey: String) async throws {
        // Trigger Cloud Function for server-side calculation
        // Implementation depends on your Cloud Function setup
        // For now, this is a placeholder that writes a trigger flag

//         let functions = Functions.functions()
//         let result = try await functions.httpsCallable("calculateStreak").call([
//             "userId": userId,
//             "streakKey": streakKey
//         ])
    }

    // MARK: - Events

    public func addEvent(userId: String, streakKey: String, event: StreakEvent) async throws {
        try eventsCollection(userId: userId, streakKey: streakKey).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, streakKey: String) async throws -> [StreakEvent] {
        try await eventsCollection(userId: userId, streakKey: streakKey)
            .order(by: StreakEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, streakKey: String) async throws {
        try await eventsCollection(userId: userId, streakKey: streakKey).deleteAllDocuments()
    }

    // MARK: - Freezes

    public func addStreakFreeze(userId: String, streakKey: String, freeze: StreakFreeze) async throws {
        try freezesCollection(userId: userId, streakKey: streakKey).document(freeze.id).setData(from: freeze, merge: false)
    }

    public func useStreakFreeze(userId: String, streakKey: String, freezeId: String) async throws {
        try await freezesCollection(userId: userId, streakKey: streakKey).updateDocument(id: freezeId, dict: [
            StreakFreeze.CodingKeys.usedDate.rawValue: Timestamp(date: Date())
        ])
    }

    public func getAllStreakFreezes(userId: String, streakKey: String) async throws -> [StreakFreeze] {
        try await freezesCollection(userId: userId, streakKey: streakKey)
            .order(by: StreakFreeze.CodingKeys.earnedDate.rawValue, descending: false)
            .getAllDocuments()
    }
}
