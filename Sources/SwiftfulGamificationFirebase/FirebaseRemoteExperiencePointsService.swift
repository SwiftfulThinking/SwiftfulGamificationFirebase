//
//  FirebaseRemoteExperiencePointsService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteExperiencePointsService: RemoteExperiencePointsService {

    private let rootCollectionName: String
    private let calculateExperiencePointsCloudFunctionName: String?

    private func userExperienceCollection(userId: String, experienceKey: String) -> CollectionReference {
        Firestore.firestore().collection(rootCollectionName)
            .document(userId)
            .collection(experienceKey)
    }

    private func currentExperiencePointsDoc(userId: String, experienceKey: String) -> DocumentReference {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .document("current_xp")
    }

    private func eventsCollection(userId: String, experienceKey: String) -> CollectionReference {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .document("xp_events")
            .collection("data")
    }

    /// Initialize the Firebase Remote Experience Points Service
    /// - Parameters:
    ///   - rootCollectionName: The root Firestore collection where all experience points data is stored.
    ///     Each user's XP data will be stored under: `{rootCollectionName}/{userId}/{experienceKey}/...`
    ///     Example: "swiftful_experience" → "swiftful_experience/user123/general/current_xp"
    ///   - calculateExperiencePointsCloudFunctionName: Cloud Function name for server-side XP calculation (e.g., "calculateExperiencePoints").
    ///     Required if useServerCalculation = true in ExperiencePointsConfiguration.
    public init(
        rootCollectionName: String,
        calculateExperiencePointsCloudFunctionName: String? = nil
    ) {
        self.rootCollectionName = rootCollectionName
        self.calculateExperiencePointsCloudFunctionName = calculateExperiencePointsCloudFunctionName
    }

    // MARK: - Current Experience Points

    public func streamCurrentExperiencePoints(userId: String, experienceKey: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error> {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .streamDocument(id: "current_xp")
    }

    public func updateCurrentExperiencePoints(userId: String, experienceKey: String, data: CurrentExperiencePointsData) async throws {
        try currentExperiencePointsDoc(userId: userId, experienceKey: experienceKey).setData(from: data, merge: true)
    }

    public func calculateExperiencePoints(userId: String, experienceKey: String, timezone: String?) async throws {
        precondition(
            calculateExperiencePointsCloudFunctionName != nil,
            "calculateExperiencePointsCloudFunctionName must be provided in init when useServerCalculation = true"
        )

        guard let cloudFunctionName = calculateExperiencePointsCloudFunctionName else {
            throw URLError(.badURL)
        }

        let functions = Functions.functions()

        var parameters: [String: Any] = [
            "userId": userId,
            "experienceKey": experienceKey,
            "configuration": [
                "experience_id": experienceKey,
                "use_server_calculation": true
            ],
            "rootCollectionName": rootCollectionName
        ]

        if let timezone = timezone {
            parameters["timezone"] = timezone
        }

        let _ = try await functions.httpsCallable(cloudFunctionName).call(parameters)
    }

    // MARK: - Events

    public func addEvent(userId: String, experienceKey: String, event: ExperiencePointsEvent) async throws {
        try eventsCollection(userId: userId, experienceKey: experienceKey).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, experienceKey: String) async throws -> [ExperiencePointsEvent] {
        try await eventsCollection(userId: userId, experienceKey: experienceKey)
            .order(by: ExperiencePointsEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, experienceKey: String) async throws {
        try await eventsCollection(userId: userId, experienceKey: experienceKey).deleteAllDocuments()
    }
}
