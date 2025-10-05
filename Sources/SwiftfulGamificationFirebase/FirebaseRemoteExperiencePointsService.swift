//
//  FirebaseRemoteExperiencePointsService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteExperiencePointsService: RemoteExperiencePointsService {

    private func userGamificationCollection(userId: String, experienceId: String) -> CollectionReference {
        Firestore.firestore().collection("swiftful_gamification")
            .document(userId)
            .collection(experienceId)
    }

    private func currentExperiencePointsDoc(userId: String, experienceId: String) -> DocumentReference {
        userGamificationCollection(userId: userId, experienceId: experienceId)
            .document("current_xp")
    }

    private func eventsCollection(userId: String, experienceId: String) -> CollectionReference {
        userGamificationCollection(userId: userId, experienceId: experienceId)
            .document("xp_events")
            .collection("data")
    }

    public init() {
    }

    // MARK: - Current Experience Points

    public func streamCurrentExperiencePoints(userId: String, experienceId: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error> {
        userGamificationCollection(userId: userId, experienceId: experienceId)
            .streamDocument(id: "current_xp")
    }

    public func updateCurrentExperiencePoints(userId: String, experienceId: String, data: CurrentExperiencePointsData) async throws {
        try currentExperiencePointsDoc(userId: userId, experienceId: experienceId).setData(from: data, merge: true)
    }

    public func calculateExperiencePoints(userId: String, experienceId: String) async throws {
        // Trigger Cloud Function for server-side calculation
        // Implementation depends on your Cloud Function setup
        // For now, this is a placeholder that writes a trigger flag

//         let functions = Functions.functions()
//         let result = try await functions.httpsCallable("calculateExperiencePoints").call([
//             "userId": userId,
//             "experienceId": experienceId
//         ])
    }

    // MARK: - Events

    public func addEvent(userId: String, experienceId: String, event: ExperiencePointsEvent) async throws {
        try eventsCollection(userId: userId, experienceId: experienceId).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, experienceId: String) async throws -> [ExperiencePointsEvent] {
        try await eventsCollection(userId: userId, experienceId: experienceId)
            .order(by: ExperiencePointsEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, experienceId: String) async throws {
        try await eventsCollection(userId: userId, experienceId: experienceId).deleteAllDocuments()
    }
}
