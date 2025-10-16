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
        if let eventsArray = firestoreData["recent_events"] as? [[String: Any]] {
            recentEvents = try eventsArray.compactMap { eventData in
                try ExperiencePointsEvent(firestoreData: eventData)
            }
        } else {
            recentEvents = nil
        }

        // Extract values to help compiler
        let experienceKey = firestoreData["experience_id"] as? String ?? ""
        let userId = firestoreData["user_id"] as? String
        let pointsAllTime = firestoreData["points_all_time"] as? Int
        let pointsToday = firestoreData["points_today"] as? Int
        let eventsTodayCount = firestoreData["events_today_count"] as? Int
        let pointsThisWeek = firestoreData["points_this_week"] as? Int
        let pointsLast7Days = firestoreData["points_last_7_days"] as? Int
        let pointsThisMonth = firestoreData["points_this_month"] as? Int
        let pointsLast30Days = firestoreData["points_last_30_days"] as? Int
        let pointsThisYear = firestoreData["points_this_year"] as? Int
        let pointsLast12Months = firestoreData["points_last_12_months"] as? Int
        let dateLastEvent = (firestoreData["date_last_event"] as? Timestamp)?.dateValue()
        let dateCreated = (firestoreData["date_created"] as? Timestamp)?.dateValue()
        let dateUpdated = (firestoreData["date_updated"] as? Timestamp)?.dateValue()

        self.init(
            experienceKey: experienceKey,
            userId: userId,
            pointsAllTime: pointsAllTime,
            pointsToday: pointsToday,
            eventsTodayCount: eventsTodayCount,
            pointsThisWeek: pointsThisWeek,
            pointsLast7Days: pointsLast7Days,
            pointsThisMonth: pointsThisMonth,
            pointsLast30Days: pointsLast30Days,
            pointsThisYear: pointsThisYear,
            pointsLast12Months: pointsLast12Months,
            dateLastEvent: dateLastEvent,
            dateCreated: dateCreated,
            dateUpdated: dateUpdated,
            recentEvents: recentEvents
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "experience_id": experienceKey
        ]

        if let userId = self.userId {
            data["user_id"] = userId
        }
        if let pointsAllTime = self.pointsAllTime {
            data["points_all_time"] = pointsAllTime
        }
        if let pointsToday = self.pointsToday {
            data["points_today"] = pointsToday
        }
        if let eventsTodayCount = self.eventsTodayCount {
            data["events_today_count"] = eventsTodayCount
        }
        if let pointsThisWeek = self.pointsThisWeek {
            data["points_this_week"] = pointsThisWeek
        }
        if let pointsLast7Days = self.pointsLast7Days {
            data["points_last_7_days"] = pointsLast7Days
        }
        if let pointsThisMonth = self.pointsThisMonth {
            data["points_this_month"] = pointsThisMonth
        }
        if let pointsLast30Days = self.pointsLast30Days {
            data["points_last_30_days"] = pointsLast30Days
        }
        if let pointsThisYear = self.pointsThisYear {
            data["points_this_year"] = pointsThisYear
        }
        if let pointsLast12Months = self.pointsLast12Months {
            data["points_last_12_months"] = pointsLast12Months
        }
        if let dateLastEvent = self.dateLastEvent {
            data["date_last_event"] = Timestamp(date: dateLastEvent)
        }
        if let dateCreated = self.dateCreated {
            data["date_created"] = Timestamp(date: dateCreated)
        }
        if let dateUpdated = self.dateUpdated {
            data["date_updated"] = Timestamp(date: dateUpdated)
        }
        if let recentEvents = self.recentEvents {
            data["recent_events"] = recentEvents.map { $0.firestoreData }
        }

        return data
    }
}
