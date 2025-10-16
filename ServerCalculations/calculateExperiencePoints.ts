/**
 * calculateExperiencePoints.ts
 *
 * Firebase Cloud Function (2nd Gen) for server-side experience points calculation
 *
 * This function performs EXACTLY the same calculation as ExperiencePointsCalculator.swift
 * It is intended to be deployed as a Firebase Callable Function
 *
 * Usage:
 * const functions = getFunctions();
 * const calculateExperiencePoints = httpsCallable(functions, 'calculateExperiencePoints');
 * await calculateExperiencePoints({ userId: 'user123', experienceKey: 'main', configuration: {...} });
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// NOTE: initializeApp() should be called in index.ts before importing this function

// ============================================================================
// MARK: - Type Definitions
// ============================================================================

interface ExperiencePointsEvent {
  id: string;
  date_created: Timestamp;
  points: number;
  metadata: Record<string, any>;
}

interface CurrentExperiencePointsData {
  experience_id: string;
  user_id?: string;
  points_all_time?: number;
  points_today?: number;
  events_today_count?: number;
  points_this_week?: number;
  points_last_7_days?: number;
  points_this_month?: number;
  points_last_30_days?: number;
  points_this_year?: number;
  points_last_12_months?: number;
  date_last_event?: Timestamp;
  date_created?: Timestamp;
  date_updated?: Timestamp;
  recent_events?: ExperiencePointsEvent[];
}

interface ExperiencePointsConfiguration {
  experience_id: string;
  use_server_calculation: boolean;
}

interface CalculateExperiencePointsRequest {
  userId: string;
  experienceKey: string;
  configuration: ExperiencePointsConfiguration;
  rootCollectionName?: string; // Optional, defaults to 'swiftful_experience_points'
  timezone?: string; // Optional, defaults to last event's timezone or 'UTC'
}

// ============================================================================
// MARK: - Helper Functions (Internal - Not Exported)
// ============================================================================

/**
 * Get Firestore collection references
 * Mirrors the structure from FirebaseRemoteExperiencePointsService.swift
 */
function getCollectionRefs(rootCollectionName: string, userId: string, experienceKey: string) {
  const db = getFirestore();
  const userExperienceCollection = db.collection(rootCollectionName).doc(userId).collection(experienceKey);

  return {
    currentDataDoc: userExperienceCollection.doc('current_xp'),
    eventsCollection: userExperienceCollection.doc('xp_events').collection('data')
  };
}

/**
 * Get all events for the user's experience points
 * Mirrors: remote.getAllEvents(userId:experienceKey:)
 */
async function getAllEvents(
  rootCollectionName: string,
  userId: string,
  experienceKey: string
): Promise<ExperiencePointsEvent[]> {
  const { eventsCollection } = getCollectionRefs(rootCollectionName, userId, experienceKey);

  const snapshot = await eventsCollection.orderBy('date_created', 'asc').get();

  return snapshot.docs.map(doc => doc.data() as ExperiencePointsEvent);
}

/**
 * Update the current experience points document
 * Mirrors: remote.updateCurrentExperiencePoints(userId:experienceKey:data:)
 */
async function updateCurrentExperiencePoints(
  rootCollectionName: string,
  userId: string,
  experienceKey: string,
  data: CurrentExperiencePointsData
): Promise<void> {
  const { currentDataDoc } = getCollectionRefs(rootCollectionName, userId, experienceKey);

  await currentDataDoc.set(data, { merge: true });
}

// ============================================================================
// MARK: - Experience Points Calculator (Pure Calculation Logic)
// ============================================================================

/**
 * Get today's event count
 * Mirrors: ExperiencePointsCalculator.getTodayEventCount()
 */
function getTodayEventCount(
  events: ExperiencePointsEvent[],
  timezone: string,
  currentDate: Date
): number {
  const todayStart = getStartOfDay(currentDate, timezone);

  return events.filter(event => {
    const eventDate = event.date_created.toDate();
    return isDateInSameDay(eventDate, todayStart, timezone);
  }).length;
}

/**
 * Get recent events from the last X calendar days
 * Mirrors: ExperiencePointsCalculator.getRecentEvents()
 */
function getRecentEvents(
  events: ExperiencePointsEvent[],
  days: number,
  timezone: string,
  currentDate: Date
): ExperiencePointsEvent[] {
  const todayStart = getStartOfDay(currentDate, timezone);

  // Calculate cutoff date: go back {days} calendar days
  let cutoffDate = new Date(todayStart);
  cutoffDate.setDate(cutoffDate.getDate() - days);

  // Filter events that fall within our date range
  const recentEvents = events.filter(event => {
    const eventDate = event.date_created.toDate();
    return eventDate >= cutoffDate;
  });

  // Group by calendar day and only include the last {days} unique days
  const eventsByDay = new Map<string, ExperiencePointsEvent[]>();

  for (const event of recentEvents) {
    const eventDate = event.date_created.toDate();
    const eventDay = getStartOfDay(eventDate, timezone);
    const dayKey = eventDay.toISOString().split('T')[0];

    if (!eventsByDay.has(dayKey)) {
      eventsByDay.set(dayKey, []);
    }
    eventsByDay.get(dayKey)!.push(event);
  }

  // Get the last {days} unique calendar days
  const sortedDays = Array.from(eventsByDay.keys()).sort();
  const lastDays = new Set(sortedDays.slice(-days));

  // Return events that fall on those days
  return recentEvents
    .filter(event => {
      const eventDate = event.date_created.toDate();
      const eventDay = getStartOfDay(eventDate, timezone);
      const dayKey = eventDay.toISOString().split('T')[0];
      return lastDays.has(dayKey);
    })
    .sort((a, b) => a.date_created.toMillis() - b.date_created.toMillis());
}

/**
 * Main experience points calculation function (internal)
 * Mirrors: ExperiencePointsCalculator.calculateExperiencePoints()
 *
 * This is the EXACT same logic as the Swift implementation
 */
function calculateExperiencePointsInternal(
  events: ExperiencePointsEvent[],
  configuration: ExperiencePointsConfiguration,
  userId: string | undefined,
  currentDate: Date,
  timezone: string
): CurrentExperiencePointsData {
  // Guard: Empty events
  if (events.length === 0) {
    const blankData: CurrentExperiencePointsData = {
      experience_id: configuration.experience_id,
      user_id: userId,
      points_all_time: 0,
      points_today: 0,
      events_today_count: 0,
      points_this_week: 0,
      points_last_7_days: 0,
      points_this_month: 0,
      points_last_30_days: 0,
      points_this_year: 0,
      points_last_12_months: 0
    };
    return blankData;
  }

  const todayStart = getStartOfDay(currentDate, timezone);

  // CALCULATE POINTS ALL TIME
  const pointsAllTime = events.reduce((sum, event) => sum + event.points, 0);

  // CALCULATE POINTS TODAY
  const pointsToday = events
    .filter(event => {
      const eventDate = event.date_created.toDate();
      return isDateInSameDay(eventDate, todayStart, timezone);
    })
    .reduce((sum, event) => sum + event.points, 0);

  // GET TODAY'S EVENT COUNT
  const eventsTodayCount = getTodayEventCount(events, timezone, currentDate);

  // CALCULATE POINTS THIS WEEK (since Sunday)
  let pointsThisWeek = 0;
  const weekInterval = getWeekInterval(currentDate, timezone);
  if (weekInterval) {
    pointsThisWeek = events
      .filter(event => {
        const eventDate = event.date_created.toDate();
        return eventDate >= weekInterval.start && eventDate <= currentDate;
      })
      .reduce((sum, event) => sum + event.points, 0);
  }

  // CALCULATE POINTS LAST 7 DAYS (rolling)
  const sevenDaysAgo = new Date(currentDate);
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  const pointsLast7Days = events
    .filter(event => {
      const eventDate = event.date_created.toDate();
      return eventDate >= sevenDaysAgo && eventDate <= currentDate;
    })
    .reduce((sum, event) => sum + event.points, 0);

  // CALCULATE POINTS THIS MONTH (since 1st)
  let pointsThisMonth = 0;
  const monthInterval = getMonthInterval(currentDate, timezone);
  if (monthInterval) {
    pointsThisMonth = events
      .filter(event => {
        const eventDate = event.date_created.toDate();
        return eventDate >= monthInterval.start && eventDate <= currentDate;
      })
      .reduce((sum, event) => sum + event.points, 0);
  }

  // CALCULATE POINTS LAST 30 DAYS (rolling)
  const thirtyDaysAgo = new Date(currentDate);
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const pointsLast30Days = events
    .filter(event => {
      const eventDate = event.date_created.toDate();
      return eventDate >= thirtyDaysAgo && eventDate <= currentDate;
    })
    .reduce((sum, event) => sum + event.points, 0);

  // CALCULATE POINTS THIS YEAR (since January 1st)
  let pointsThisYear = 0;
  const yearInterval = getYearInterval(currentDate, timezone);
  if (yearInterval) {
    pointsThisYear = events
      .filter(event => {
        const eventDate = event.date_created.toDate();
        return eventDate >= yearInterval.start && eventDate <= currentDate;
      })
      .reduce((sum, event) => sum + event.points, 0);
  }

  // CALCULATE POINTS LAST 12 MONTHS (rolling)
  const twelveMonthsAgo = new Date(currentDate);
  twelveMonthsAgo.setMonth(twelveMonthsAgo.getMonth() - 12);
  const pointsLast12Months = events
    .filter(event => {
      const eventDate = event.date_created.toDate();
      return eventDate >= twelveMonthsAgo && eventDate <= currentDate;
    })
    .reduce((sum, event) => sum + event.points, 0);

  // LAST EVENT INFO
  const lastEvent = events.reduce((latest, event) => {
    return event.date_created.toMillis() > latest.date_created.toMillis() ? event : latest;
  });

  // GET RECENT EVENTS (last 60 days)
  const recentEvents = getRecentEvents(events, 60, timezone, currentDate);

  const data: CurrentExperiencePointsData = {
    experience_id: configuration.experience_id,
    user_id: userId,
    points_all_time: pointsAllTime,
    points_today: pointsToday,
    events_today_count: eventsTodayCount,
    points_this_week: pointsThisWeek,
    points_last_7_days: pointsLast7Days,
    points_this_month: pointsThisMonth,
    points_last_30_days: pointsLast30Days,
    points_this_year: pointsThisYear,
    points_last_12_months: pointsLast12Months,
    date_last_event: lastEvent.date_created,
    date_created: events.length > 0 ? events[0].date_created : undefined,
    date_updated: Timestamp.fromDate(currentDate),
    recent_events: recentEvents
  };

  return data;
}

// ============================================================================
// MARK: - Date Utilities
// ============================================================================

/**
 * Get start of day in a specific timezone
 * Returns a Date representing midnight (00:00:00) in the specified timezone
 *
 * This matches Swift's calendar.startOfDay(for:) behavior:
 * Takes any date and returns the UTC timestamp that represents midnight in the given timezone
 *
 * Based on: https://stackoverflow.com/questions/36031220
 */
function getStartOfDay(date: Date, timezone: string): Date {
  // Get the hour, minute, and second components in the target timezone
  const parts = Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hourCycle: 'h23',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric'
  }).formatToParts(date);

  const hour = parseInt(parts.find(p => p.type === 'hour')!.value);
  const minute = parseInt(parts.find(p => p.type === 'minute')!.value);
  const second = parseInt(parts.find(p => p.type === 'second')!.value);

  // Subtract the time components to get midnight in the target timezone
  // This works because we're subtracting the timezone's local time from the UTC timestamp
  return new Date(
    1000 * Math.floor(
      (date.getTime() - hour * 3600000 - minute * 60000 - second * 1000) / 1000
    )
  );
}

/**
 * Check if two dates are in the same day
 */
function isDateInSameDay(date1: Date, date2: Date, timezone: string): boolean {
  const day1 = getStartOfDay(date1, timezone);
  const day2 = getStartOfDay(date2, timezone);
  return day1.getTime() === day2.getTime();
}

/**
 * Get week interval (Sunday to Saturday)
 */
function getWeekInterval(date: Date, timezone: string): { start: Date; end: Date } | null {
  try {
    const dateInTz = getStartOfDay(date, timezone);

    // Get day of week (0 = Sunday, 6 = Saturday)
    const dayOfWeek = dateInTz.getDay();

    // Calculate days to subtract to get to Sunday
    const start = new Date(dateInTz);
    start.setDate(start.getDate() - dayOfWeek);

    const end = new Date(start);
    end.setDate(end.getDate() + 6);
    end.setHours(23, 59, 59, 999);

    return { start, end };
  } catch {
    return null;
  }
}

/**
 * Get month interval (1st to last day)
 * Returns midnight on the 1st and 23:59:59 on the last day of the month in the target timezone
 */
function getMonthInterval(date: Date, timezone: string): { start: Date; end: Date } | null {
  try {
    // Get year/month/day in the target timezone
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).formatToParts(date);

    const year = parseInt(parts.find(p => p.type === 'year')!.value);
    const month = parseInt(parts.find(p => p.type === 'month')!.value);

    // Create a date for the 1st of this month at noon in the target timezone
    const firstDayNoon = new Date(Date.UTC(year, month - 1, 1, 12, 0, 0, 0));

    // Get midnight on the 1st in the target timezone
    const start = getStartOfDay(firstDayNoon, timezone);

    // Last day of month: create a date for the 1st of next month, then subtract 1 day
    const nextMonth = new Date(Date.UTC(year, month, 1, 12, 0, 0, 0));
    const lastDayNoon = new Date(nextMonth.getTime() - (24 * 60 * 60 * 1000));

    // Get midnight on the last day, then set to end of day
    const endDayStart = getStartOfDay(lastDayNoon, timezone);
    const end = new Date(endDayStart.getTime() + (24 * 60 * 60 * 1000) - 1);

    return { start, end };
  } catch {
    return null;
  }
}

/**
 * Get year interval (January 1st to December 31st)
 * Returns midnight on Jan 1st and 23:59:59 on Dec 31st in the target timezone
 */
function getYearInterval(date: Date, timezone: string): { start: Date; end: Date } | null {
  try {
    // Get year in the target timezone
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric'
    }).formatToParts(date);

    const year = parseInt(parts.find(p => p.type === 'year')!.value);

    // Create a date for Jan 1st at noon in the target timezone
    const jan1Noon = new Date(Date.UTC(year, 0, 1, 12, 0, 0, 0));

    // Get midnight on Jan 1st in the target timezone
    const start = getStartOfDay(jan1Noon, timezone);

    // Create a date for Dec 31st at noon
    const dec31Noon = new Date(Date.UTC(year, 11, 31, 12, 0, 0, 0));

    // Get midnight on Dec 31st, then set to end of day
    const endDayStart = getStartOfDay(dec31Noon, timezone);
    const end = new Date(endDayStart.getTime() + (24 * 60 * 60 * 1000) - 1);

    return { start, end };
  } catch {
    return null;
  }
}

// ============================================================================
// MARK: - Main Cloud Function
// ============================================================================

/**
 * calculateExperiencePoints - Firebase Callable Function (2nd Gen)
 *
 * Performs server-side experience points calculation EXACTLY as client-side ExperiencePointsCalculator
 *
 * Mirrors: ExperiencePointsManager.calculateExperiencePointsAsync() (lines 168-196)
 */
export const calculateExperiencePoints = onCall<CalculateExperiencePointsRequest>(
  async (request) => {
    const { userId, experienceKey, configuration, rootCollectionName = 'swiftful_experience_points', timezone: requestTimezone } = request.data;

    // Validate input
    if (!userId || !experienceKey || !configuration) {
      throw new HttpsError(
        'invalid-argument',
        'Missing required parameters: userId, experienceKey, or configuration'
      );
    }

    try {
      // Get all events (same as client-side line 181)
      const events = await getAllEvents(rootCollectionName, userId, experienceKey);

      // Calculate experience points (same as client-side lines 183-187)
      const currentDate = new Date();
      // Use passed timezone or default to UTC (events don't store timezone like StreakEvents do)
      const timezone = requestTimezone || 'UTC';

      const calculatedData = calculateExperiencePointsInternal(
        events,
        configuration,
        userId,
        currentDate,
        timezone
      );

      // Update Firestore (same as client-side line 190)
      await updateCurrentExperiencePoints(rootCollectionName, userId, experienceKey, calculatedData);

      // Success - no return value needed (same as client-side)
      return { success: true };

    } catch (error) {
      // Throw errors the same places the client-side calculation throws errors
      throw new HttpsError(
        'internal',
        `Failed to calculate experience points: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }
);
