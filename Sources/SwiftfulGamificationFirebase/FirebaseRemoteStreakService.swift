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

    private func userGamificationCollection(userId: String, streakId: String) -> CollectionReference {
        Firestore.firestore().collection("swiftful_gamification")
            .document(userId)
            .collection(streakId)
    }

    private func currentStreakDoc(userId: String, streakId: String) -> DocumentReference {
        userGamificationCollection(userId: userId, streakId: streakId)
            .document("current_streak")
    }

    private func eventsCollection(userId: String, streakId: String) -> CollectionReference {
        userGamificationCollection(userId: userId, streakId: streakId)
            .document("streak_events")
            .collection("data")
    }

    private func freezesCollection(userId: String, streakId: String) -> CollectionReference {
        userGamificationCollection(userId: userId, streakId: streakId)
            .document("streak_freezes")
            .collection("data")
    }

    public init() {
    }

    // MARK: - Current Streak

    public func streamCurrentStreak(userId: String, streakId: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        userGamificationCollection(userId: userId, streakId: streakId)
            .streamDocument(id: "current_streak")
    }

    public func updateCurrentStreak(userId: String, streakId: String, streak: CurrentStreakData) async throws {
        try currentStreakDoc(userId: userId, streakId: streakId).setData(from: streak, merge: true)
    }

    public func calculateStreak(userId: String, streakId: String) async throws {
        // Trigger Cloud Function for server-side calculation
        // Implementation depends on your Cloud Function setup
        // For now, this is a placeholder that writes a trigger flag

//         let functions = Functions.functions()
//         let result = try await functions.httpsCallable("calculateStreak").call([
//             "userId": userId,
//             "streakId": streakId
//         ])
    }

    // MARK: - Events

    public func addEvent(userId: String, streakId: String, event: StreakEvent) async throws {
        try eventsCollection(userId: userId, streakId: streakId).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, streakId: String) async throws -> [StreakEvent] {
        try await eventsCollection(userId: userId, streakId: streakId)
            .order(by: StreakEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, streakId: String) async throws {
        try await eventsCollection(userId: userId, streakId: streakId).deleteAllDocuments()
    }

    // MARK: - Freezes

    public func addStreakFreeze(userId: String, streakId: String, freeze: StreakFreeze) async throws {
        try freezesCollection(userId: userId, streakId: streakId).document(freeze.id).setData(from: freeze, merge: false)
    }

    public func useStreakFreeze(userId: String, streakId: String, freezeId: String) async throws {
        try await freezesCollection(userId: userId, streakId: streakId).updateDocument(id: freezeId, dict: [
            StreakFreeze.CodingKeys.usedDate.rawValue: Timestamp(date: Date())
        ])
    }

    public func getAllStreakFreezes(userId: String, streakId: String) async throws -> [StreakFreeze] {
        try await freezesCollection(userId: userId, streakId: streakId)
            .order(by: StreakFreeze.CodingKeys.earnedDate.rawValue, descending: false)
            .getAllDocuments()
    }
}
