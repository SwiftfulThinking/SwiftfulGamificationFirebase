//
//  CurrentStreakData+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulGamification

extension CurrentStreakData {

    /// Initialize from Firestore document data
    public init(firestoreData: [String: Any]) throws {
        // Parse recent events if present
        let recentEvents: [StreakEvent]?
        if let eventsArray = firestoreData[CodingKeys.recentEvents.rawValue] as? [[String: Any]] {
            recentEvents = try eventsArray.compactMap { eventData in
                try StreakEvent(firestoreData: eventData)
            }
        } else {
            recentEvents = nil
        }

        self.init(
            streakId: firestoreData[CodingKeys.streakId.rawValue] as? String ?? "",
            currentStreak: firestoreData[CodingKeys.currentStreak.rawValue] as? Int,
            longestStreak: firestoreData[CodingKeys.longestStreak.rawValue] as? Int,
            lastEventDate: (firestoreData[CodingKeys.lastEventDate.rawValue] as? Timestamp)?.dateValue(),
            lastEventTimezone: firestoreData[CodingKeys.lastEventTimezone.rawValue] as? String,
            streakStartDate: (firestoreData[CodingKeys.streakStartDate.rawValue] as? Timestamp)?.dateValue(),
            totalEvents: firestoreData[CodingKeys.totalEvents.rawValue] as? Int,
            freezesRemaining: firestoreData[CodingKeys.freezesRemaining.rawValue] as? Int,
            createdAt: (firestoreData[CodingKeys.createdAt.rawValue] as? Timestamp)?.dateValue(),
            updatedAt: (firestoreData[CodingKeys.updatedAt.rawValue] as? Timestamp)?.dateValue(),
            eventsRequiredPerDay: firestoreData[CodingKeys.eventsRequiredPerDay.rawValue] as? Int,
            todayEventCount: firestoreData[CodingKeys.todayEventCount.rawValue] as? Int,
            recentEvents: recentEvents
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.streakId.rawValue: streakId
        ]

        if let currentStreak = currentStreak {
            data[CodingKeys.currentStreak.rawValue] = currentStreak
        }
        if let longestStreak = longestStreak {
            data[CodingKeys.longestStreak.rawValue] = longestStreak
        }
        if let lastEventDate = lastEventDate {
            data[CodingKeys.lastEventDate.rawValue] = Timestamp(date: lastEventDate)
        }
        if let lastEventTimezone = lastEventTimezone {
            data[CodingKeys.lastEventTimezone.rawValue] = lastEventTimezone
        }
        if let streakStartDate = streakStartDate {
            data[CodingKeys.streakStartDate.rawValue] = Timestamp(date: streakStartDate)
        }
        if let totalEvents = totalEvents {
            data[CodingKeys.totalEvents.rawValue] = totalEvents
        }
        if let freezesRemaining = freezesRemaining {
            data[CodingKeys.freezesRemaining.rawValue] = freezesRemaining
        }
        if let createdAt = createdAt {
            data[CodingKeys.createdAt.rawValue] = Timestamp(date: createdAt)
        }
        if let updatedAt = updatedAt {
            data[CodingKeys.updatedAt.rawValue] = Timestamp(date: updatedAt)
        }
        if let eventsRequiredPerDay = eventsRequiredPerDay {
            data[CodingKeys.eventsRequiredPerDay.rawValue] = eventsRequiredPerDay
        }
        if let todayEventCount = todayEventCount {
            data[CodingKeys.todayEventCount.rawValue] = todayEventCount
        }
        if let recentEvents = recentEvents {
            data[CodingKeys.recentEvents.rawValue] = recentEvents.map { $0.firestoreData }
        }

        return data
    }
}
