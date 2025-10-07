//
//  CurrentExperiencePointsData+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulGamification

extension CurrentExperiencePointsData {

    /// Initialize from Firestore document data
    public init(firestoreData: [String: Any]) throws {
        // Parse recent events if present
        let recentEvents: [ExperiencePointsEvent]?
        if let eventsArray = firestoreData[CodingKeys.recentEvents.rawValue] as? [[String: Any]] {
            recentEvents = try eventsArray.compactMap { eventData in
                try ExperiencePointsEvent(firestoreData: eventData)
            }
        } else {
            recentEvents = nil
        }

        self.init(
            experienceKey: firestoreData[CodingKeys.experienceKey.rawValue] as? String ?? "",
            totalPoints: firestoreData[CodingKeys.totalPoints.rawValue] as? Int,
            totalEvents: firestoreData[CodingKeys.totalEvents.rawValue] as? Int,
            todayEventCount: firestoreData[CodingKeys.todayEventCount.rawValue] as? Int,
            lastEventDate: (firestoreData[CodingKeys.lastEventDate.rawValue] as? Timestamp)?.dateValue(),
            createdAt: (firestoreData[CodingKeys.createdAt.rawValue] as? Timestamp)?.dateValue(),
            updatedAt: (firestoreData[CodingKeys.updatedAt.rawValue] as? Timestamp)?.dateValue(),
            recentEvents: recentEvents
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.experienceKey.rawValue: experienceKey
        ]

        if let totalPoints = totalPoints {
            data[CodingKeys.totalPoints.rawValue] = totalPoints
        }
        if let totalEvents = totalEvents {
            data[CodingKeys.totalEvents.rawValue] = totalEvents
        }
        if let todayEventCount = todayEventCount {
            data[CodingKeys.todayEventCount.rawValue] = todayEventCount
        }
        if let lastEventDate = lastEventDate {
            data[CodingKeys.lastEventDate.rawValue] = Timestamp(date: lastEventDate)
        }
        if let createdAt = createdAt {
            data[CodingKeys.createdAt.rawValue] = Timestamp(date: createdAt)
        }
        if let updatedAt = updatedAt {
            data[CodingKeys.updatedAt.rawValue] = Timestamp(date: updatedAt)
        }
        if let recentEvents = recentEvents {
            data[CodingKeys.recentEvents.rawValue] = recentEvents.map { $0.firestoreData }
        }

        return data
    }
}
