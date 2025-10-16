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

        // Parse freezes available if present
        let freezesAvailable: [StreakFreeze]?
        if let freezesArray = firestoreData[CodingKeys.freezesAvailable.rawValue] as? [[String: Any]] {
            freezesAvailable = try freezesArray.compactMap { freezeData in
                try StreakFreeze(firestoreData: freezeData)
            }
        } else {
            freezesAvailable = nil
        }

        self.init(
            streakKey: firestoreData[CodingKeys.streakKey.rawValue] as? String ?? "",
            userId: firestoreData[CodingKeys.userId.rawValue] as? String,
            currentStreak: firestoreData[CodingKeys.currentStreak.rawValue] as? Int,
            longestStreak: firestoreData[CodingKeys.longestStreak.rawValue] as? Int,
            dateLastEvent: (firestoreData[CodingKeys.dateLastEvent.rawValue] as? Timestamp)?.dateValue(),
            lastEventTimezone: firestoreData[CodingKeys.lastEventTimezone.rawValue] as? String,
            dateStreakStart: (firestoreData[CodingKeys.dateStreakStart.rawValue] as? Timestamp)?.dateValue(),
            totalEvents: firestoreData[CodingKeys.totalEvents.rawValue] as? Int,
            freezesAvailable: freezesAvailable,
            freezesAvailableCount: firestoreData[CodingKeys.freezesAvailableCount.rawValue] as? Int,
            dateCreated: (firestoreData[CodingKeys.dateCreated.rawValue] as? Timestamp)?.dateValue(),
            dateUpdated: (firestoreData[CodingKeys.dateUpdated.rawValue] as? Timestamp)?.dateValue(),
            eventsRequiredPerDay: firestoreData[CodingKeys.eventsRequiredPerDay.rawValue] as? Int,
            todayEventCount: firestoreData[CodingKeys.todayEventCount.rawValue] as? Int,
            recentEvents: recentEvents
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.streakKey.rawValue: streakKey
        ]

        if let userId = userId {
            data[CodingKeys.userId.rawValue] = userId
        }
        if let currentStreak = currentStreak {
            data[CodingKeys.currentStreak.rawValue] = currentStreak
        }
        if let longestStreak = longestStreak {
            data[CodingKeys.longestStreak.rawValue] = longestStreak
        }
        if let dateLastEvent = dateLastEvent {
            data[CodingKeys.dateLastEvent.rawValue] = Timestamp(date: dateLastEvent)
        }
        if let lastEventTimezone = lastEventTimezone {
            data[CodingKeys.lastEventTimezone.rawValue] = lastEventTimezone
        }
        if let dateStreakStart = dateStreakStart {
            data[CodingKeys.dateStreakStart.rawValue] = Timestamp(date: dateStreakStart)
        }
        if let totalEvents = totalEvents {
            data[CodingKeys.totalEvents.rawValue] = totalEvents
        }
        if let freezesAvailable = freezesAvailable {
            data[CodingKeys.freezesAvailable.rawValue] = freezesAvailable.map { $0.firestoreData }
        }
        if let freezesAvailableCount = freezesAvailableCount {
            data[CodingKeys.freezesAvailableCount.rawValue] = freezesAvailableCount
        }
        if let dateCreated = dateCreated {
            data[CodingKeys.dateCreated.rawValue] = Timestamp(date: dateCreated)
        }
        if let dateUpdated = dateUpdated {
            data[CodingKeys.dateUpdated.rawValue] = Timestamp(date: dateUpdated)
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
