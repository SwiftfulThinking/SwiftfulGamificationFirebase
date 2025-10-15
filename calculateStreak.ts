/**
 * calculateStreak.ts
 *
 * Firebase Cloud Function (2nd Gen) for server-side streak calculation
 *
 * This function performs EXACTLY the same calculation as StreakCalculator.swift
 * It is intended to be deployed as a Firebase Callable Function
 *
 * Usage:
 * const functions = getFunctions();
 * const calculateStreak = httpsCallable(functions, 'calculateStreak');
 * await calculateStreak({ userId: 'user123', streakKey: 'workout', configuration: {...} });
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { initializeApp } from 'firebase-admin/app';

// Initialize Firebase Admin
initializeApp();

// ============================================================================
// MARK: - Type Definitions
// ============================================================================

interface StreakEvent {
  id: string;
  date_created: Timestamp;
  timezone: string;
  is_freeze: boolean;
  freeze_id?: string;
  metadata: Record<string, any>;
}

interface StreakFreeze {
  id: string;
  date_earned?: Timestamp;
  date_used?: Timestamp;
  date_expires?: Timestamp;
}

interface CurrentStreakData {
  streak_id: string;
  user_id?: string;
  current_streak?: number;
  longest_streak?: number;
  date_last_event?: Timestamp;
  last_event_timezone?: string;
  date_streak_start?: Timestamp;
  total_events?: number;
  freezes_available?: StreakFreeze[];
  freezes_available_count?: number;
  date_created?: Timestamp;
  date_updated?: Timestamp;
  events_required_per_day?: number;
  today_event_count?: number;
  recent_events?: StreakEvent[];
}

interface StreakConfiguration {
  streak_id: string;
  events_required_per_day: number;
  use_server_calculation: boolean;
  leeway_hours: number;
  freeze_behavior: 'noFreezes' | 'autoConsumeFreezes' | 'manuallyConsumeFreezes';
}

interface FreezeConsumption {
  freezeId: string;
  date: Date;
}

interface CalculateStreakRequest {
  userId: string;
  streakKey: string;
  configuration: StreakConfiguration;
  rootCollectionName?: string; // Optional, defaults to 'swiftful_streaks'
  timezone?: string; // Optional, defaults to last event's timezone or 'UTC'
}

// ============================================================================
// MARK: - Helper Functions (Internal - Not Exported)
// ============================================================================

/**
 * Get Firestore collection references
 * Mirrors the structure from FirebaseRemoteStreakService.swift
 */
function getCollectionRefs(rootCollectionName: string, userId: string, streakKey: string) {
  const db = getFirestore();
  const userStreakCollection = db.collection(rootCollectionName).doc(userId).collection(streakKey);

  return {
    currentStreakDoc: userStreakCollection.doc('current_streak'),
    eventsCollection: userStreakCollection.doc('streak_events').collection('data'),
    freezesCollection: userStreakCollection.doc('streak_freezes').collection('data')
  };
}

/**
 * Get all events for the user's streak
 * Mirrors: remote.getAllEvents(userId:streakKey:)
 */
async function getAllEvents(
  rootCollectionName: string,
  userId: string,
  streakKey: string
): Promise<StreakEvent[]> {
  const { eventsCollection } = getCollectionRefs(rootCollectionName, userId, streakKey);

  const snapshot = await eventsCollection.orderBy('date_created', 'asc').get();

  return snapshot.docs.map(doc => doc.data() as StreakEvent);
}

/**
 * Get all streak freezes for the user's streak
 * Mirrors: remote.getAllStreakFreezes(userId:streakKey:)
 */
async function getAllStreakFreezes(
  rootCollectionName: string,
  userId: string,
  streakKey: string
): Promise<StreakFreeze[]> {
  const { freezesCollection } = getCollectionRefs(rootCollectionName, userId, streakKey);

  const snapshot = await freezesCollection.orderBy('date_earned', 'asc').get();

  return snapshot.docs.map(doc => doc.data() as StreakFreeze);
}

/**
 * Add a freeze event
 * Mirrors: remote.addEvent(userId:streakKey:event:)
 */
async function addEvent(
  rootCollectionName: string,
  userId: string,
  streakKey: string,
  event: StreakEvent
): Promise<void> {
  const { eventsCollection } = getCollectionRefs(rootCollectionName, userId, streakKey);

  await eventsCollection.doc(event.id).set(event);
}

/**
 * Mark a freeze as used
 * Mirrors: remote.useStreakFreeze(userId:streakKey:freezeId:)
 */
async function useStreakFreeze(
  rootCollectionName: string,
  userId: string,
  streakKey: string,
  freezeId: string
): Promise<void> {
  const { freezesCollection } = getCollectionRefs(rootCollectionName, userId, streakKey);

  await freezesCollection.doc(freezeId).update({
    date_used: Timestamp.now()
  });
}

/**
 * Update the current streak document
 * Mirrors: remote.updateCurrentStreak(userId:streakKey:streak:)
 */
async function updateCurrentStreak(
  rootCollectionName: string,
  userId: string,
  streakKey: string,
  streak: CurrentStreakData
): Promise<void> {
  const { currentStreakDoc } = getCollectionRefs(rootCollectionName, userId, streakKey);

  await currentStreakDoc.set(streak, { merge: true });
}

// ============================================================================
// MARK: - Streak Calculator (Pure Calculation Logic)
// ============================================================================

/**
 * Get today's event count
 * Mirrors: StreakCalculator.getTodayEventCount()
 */
function getTodayEventCount(
  events: StreakEvent[],
  timezone: string,
  currentDate: Date
): number {
  // Create timezone-aware date calculation
  const todayStart = getStartOfDay(currentDate, timezone);

  return events.filter(event => {
    const eventDate = event.date_created.toDate();
    return isDateInSameDay(eventDate, todayStart, timezone);
  }).length;
}

/**
 * Get recent events from the last X calendar days (accounting for leeway)
 * Mirrors: StreakCalculator.getRecentEvents()
 */
function getRecentEvents(
  events: StreakEvent[],
  days: number,
  timezone: string,
  leewayHours: number,
  currentDate: Date
): StreakEvent[] {
  const todayStart = getStartOfDay(currentDate, timezone);

  // Calculate cutoff date: go back {days} calendar days
  let cutoffDate = new Date(todayStart);
  cutoffDate.setDate(cutoffDate.getDate() - days);

  // Subtract leeway hours from cutoff to ensure we capture events that fall
  // within the leeway window at the start of the cutoff day
  if (leewayHours > 0) {
    cutoffDate = new Date(cutoffDate.getTime() - (leewayHours * 60 * 60 * 1000));
  }

  // Filter events that fall within our date range
  const recentEvents = events.filter(event => {
    const eventDate = event.date_created.toDate();
    return eventDate >= cutoffDate;
  });

  // Group by calendar day (accounting for leeway) and only include the last {days} unique days
  const eventsByDay = new Map<string, StreakEvent[]>();

  for (const event of recentEvents) {
    const eventDate = event.date_created.toDate();
    let eventDay = getStartOfDay(eventDate, timezone);

    // If event is within leeway hours after midnight, count it as previous day
    if (leewayHours > 0) {
      const hoursSinceMidnight = getHoursBetween(eventDay, eventDate);
      if (hoursSinceMidnight <= leewayHours) {
        eventDay = new Date(eventDay);
        eventDay.setDate(eventDay.getDate() - 1);
      }
    }

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
      let eventDay = getStartOfDay(eventDate, timezone);

      if (leewayHours > 0) {
        const hoursSinceMidnight = getHoursBetween(eventDay, eventDate);
        if (hoursSinceMidnight <= leewayHours) {
          eventDay = new Date(eventDay);
          eventDay.setDate(eventDay.getDate() - 1);
        }
      }

      const dayKey = eventDay.toISOString().split('T')[0];
      return lastDays.has(dayKey);
    })
    .sort((a, b) => a.date_created.toMillis() - b.date_created.toMillis());
}

/**
 * Calculate gap days between last event and today
 * Mirrors: StreakCalculator.calculateGapDays()
 */
function calculateGapDays(
  lastEventDate: Date,
  currentDate: Date,
  timezone: string
): Date[] {
  const lastEventDay = getStartOfDay(lastEventDate, timezone);
  const today = getStartOfDay(currentDate, timezone);

  // Calculate how many days need to be filled (excluding today)
  const daysSinceLastEvent = getDaysBetween(lastEventDay, today, timezone);
  const daysToFill = Math.max(0, daysSinceLastEvent - 1);

  if (daysToFill <= 0) {
    return [];
  }

  // Generate array of dates that need freezes
  const gapDays: Date[] = [];
  let currentDay = new Date(lastEventDay);
  currentDay.setDate(currentDay.getDate() + 1);

  for (let i = 0; i < daysToFill; i++) {
    gapDays.push(new Date(currentDay));
    currentDay.setDate(currentDay.getDate() + 1);
  }

  return gapDays;
}

/**
 * Select freezes to consume for specific days using FIFO (First In First Out) ordering
 * Mirrors: StreakCalculator.selectFreezesForDays()
 */
function selectFreezesForDays(
  daysToFill: Date[],
  availableFreezes: StreakFreeze[]
): FreezeConsumption[] {
  if (daysToFill.length === 0 || availableFreezes.length === 0) {
    return [];
  }

  // Sort freezes FIFO - oldest first (by date_earned)
  const sortedFreezes = [...availableFreezes].sort((a, b) => {
    const aDate = a.date_earned?.toMillis() ?? 0;
    const bDate = b.date_earned?.toMillis() ?? 0;
    return aDate - bDate;
  });

  // Take as many freezes as we have days (or all available freezes if fewer)
  const freezesToUse = sortedFreezes.slice(0, daysToFill.length);

  // Map each freeze to its corresponding day
  const consumptions: FreezeConsumption[] = [];
  for (let i = 0; i < freezesToUse.length; i++) {
    consumptions.push({
      freezeId: freezesToUse[i].id,
      date: daysToFill[i]
    });
  }

  return consumptions;
}

/**
 * Main streak calculation function
 * Mirrors: StreakCalculator.calculateStreak()
 *
 * This is the EXACT same logic as the Swift implementation
 */
function calculateStreak(
  events: StreakEvent[],
  freezes: StreakFreeze[],
  configuration: StreakConfiguration,
  userId: string | undefined,
  currentDate: Date,
  timezone: string
): { streak: CurrentStreakData; freezeConsumptions: FreezeConsumption[] } {
  // Guard: Empty events
  if (events.length === 0) {
    const availableFreezes = freezes.filter(f => isAvailable(f, currentDate));
    const blankStreak: CurrentStreakData = {
      streak_id: configuration.streak_id,
      user_id: userId,
      current_streak: 0,
      longest_streak: 0,
      total_events: 0,
      freezes_available: availableFreezes,
      freezes_available_count: availableFreezes.length,
      date_updated: Timestamp.fromDate(currentDate),
      events_required_per_day: configuration.events_required_per_day,
      today_event_count: 0
    };
    return { streak: blankStreak, freezeConsumptions: [] };
  }

  // GROUP EVENTS BY DAY
  const eventsByDay = new Map<string, StreakEvent[]>();

  for (const event of events) {
    const eventDate = event.date_created.toDate();
    const dayStart = getStartOfDay(eventDate, timezone);
    const dayKey = dayStart.toISOString().split('T')[0];

    if (!eventsByDay.has(dayKey)) {
      eventsByDay.set(dayKey, []);
    }
    eventsByDay.get(dayKey)!.push(event);
  }

  // GOAL-BASED MODE: Filter days that met the goal
  let qualifyingDays: Date[];
  if (configuration.events_required_per_day > 1) {
    qualifyingDays = Array.from(eventsByDay.entries())
      .filter(([_, dayEvents]) => dayEvents.length >= configuration.events_required_per_day)
      .map(([dayKey, _]) => new Date(dayKey))
      .sort((a, b) => a.getTime() - b.getTime());
  } else {
    // BASIC MODE: Any day with at least 1 event qualifies
    qualifyingDays = Array.from(eventsByDay.keys())
      .map(dayKey => new Date(dayKey))
      .sort((a, b) => a.getTime() - b.getTime());
  }

  // CALCULATE CURRENT STREAK (walk backwards from today) with freeze support
  let currentStreak = 0;
  let expectedDate = getStartOfDay(currentDate, timezone);
  const freezeConsumptions: FreezeConsumption[] = [];
  let availableFreezes = freezes
    .filter(f => isAvailable(f, currentDate))
    .sort((a, b) => {
      const aDate = a.date_earned?.toMillis() ?? 0;
      const bDate = b.date_earned?.toMillis() ?? 0;
      return aDate - bDate;
    });

  // Apply leeway: Extend "today" window
  if (configuration.leeway_hours > 0) {
    const hoursSinceMidnight = getHoursBetween(expectedDate, currentDate);

    if (hoursSinceMidnight <= configuration.leeway_hours) {
      expectedDate = new Date(expectedDate);
      expectedDate.setDate(expectedDate.getDate() - 1);
    }
  }

  // AUTO-CONSUME FREEZES: Fill gap between last event and today (if applicable)
  if (configuration.freeze_behavior === 'autoConsumeFreezes' && qualifyingDays.length > 0) {
    const lastEvent = qualifyingDays[qualifyingDays.length - 1];
    const lastEventDay = getStartOfDay(lastEvent, timezone);
    const today = getStartOfDay(currentDate, timezone);

    // Calculate gap between last event and today
    const daysSinceLastEvent = getDaysBetween(lastEventDay, today, timezone);
    const daysToFill = Math.max(0, daysSinceLastEvent - 1);

    // Only auto-consume if there's a gap AND we have enough freezes to fill the entire gap
    if (daysToFill > 0 && availableFreezes.length >= daysToFill) {
      // Calculate which days need to be filled
      const gapDays = calculateGapDays(lastEvent, currentDate, timezone);

      // Use exactly as many freezes as needed to fill the gap
      for (let i = 0; i < gapDays.length; i++) {
        const freeze = availableFreezes.shift()!;
        freezeConsumptions.push({ freezeId: freeze.id, date: gapDays[i] });
      }
    }
  }

  // Track if we've started counting (to handle "today has no event" edge case)
  let hasStartedStreak = false;

  for (let i = qualifyingDays.length - 1; i >= 0; i--) {
    const eventDay = qualifyingDays[i];

    if (isDateInSameDay(eventDay, expectedDate, timezone)) {
      // Only increment if this day has at least one non-freeze event
      const dayKey = getStartOfDay(eventDay, timezone).toISOString().split('T')[0];
      const dayEvents = eventsByDay.get(dayKey) ?? [];
      if (dayEvents.some(e => !e.is_freeze)) {
        currentStreak += 1;
      }
      expectedDate = new Date(expectedDate);
      expectedDate.setDate(expectedDate.getDate() - 1);
      hasStartedStreak = true;
    } else if (eventDay < expectedDate) {
      // Gap found - calculate gap size
      const daysBetween = getDaysBetween(eventDay, expectedDate, timezone);

      // EDGE CASE FIX: If we haven't started counting yet (no event today) and gap is only 1 day,
      // this is the "at risk" state - yesterday's event should still count
      // BUT: Only if we're checking on the same day as expectedDate (meaning we're still "today")
      // OR if leeway is enabled (grace period applies)
      const checkingOnExpectedDay = isDateInSameDay(currentDate, expectedDate, timezone);
      const leewayApplied = configuration.leeway_hours > 0;

      if (!hasStartedStreak && daysBetween === 1 && (checkingOnExpectedDay || leewayApplied)) {
        // Only increment if this day has at least one non-freeze event
        const dayKey = getStartOfDay(eventDay, timezone).toISOString().split('T')[0];
        const dayEvents = eventsByDay.get(dayKey) ?? [];
        if (dayEvents.some(e => !e.is_freeze)) {
          currentStreak += 1;
        }
        // Move expectedDate to the event we just counted, then back one more day for the next check
        expectedDate = new Date(eventDay);
        expectedDate.setDate(expectedDate.getDate() - 1);
        hasStartedStreak = true;
        continue;
      }

      // Gap found with no freeze to fill - streak is broken
      break;
    }
  }

  // CALCULATE LONGEST STREAK
  let longestStreak = 0;
  let tempStreak = 0;
  let previousDay: Date | null = null;

  for (const eventDay of qualifyingDays) {
    // Only count days with non-freeze events
    const dayKey = getStartOfDay(eventDay, timezone).toISOString().split('T')[0];
    const dayEvents = eventsByDay.get(dayKey) ?? [];
    const hasRealEvents = dayEvents.some(e => !e.is_freeze);

    if (previousDay !== null) {
      const dayDiff = getDaysBetween(previousDay, eventDay, timezone);
      if (dayDiff === 1) {
        if (hasRealEvents) {
          tempStreak += 1;
        }
      } else {
        longestStreak = Math.max(longestStreak, tempStreak);
        tempStreak = hasRealEvents ? 1 : 0;
      }
    } else {
      tempStreak = hasRealEvents ? 1 : 0;
    }
    previousDay = eventDay;
  }
  longestStreak = Math.max(longestStreak, tempStreak);
  longestStreak = Math.max(longestStreak, currentStreak);

  // GET TODAY'S EVENT COUNT (for goal progress)
  const todayEventCount = getTodayEventCount(events, timezone, currentDate);

  // LAST EVENT INFO
  const lastEvent = events.reduce((latest, event) => {
    return event.date_created.toMillis() > latest.date_created.toMillis() ? event : latest;
  });

  // STREAK START DATE
  let streakStartDate: Timestamp | undefined = undefined;
  if (currentStreak > 0) {
    // Calculate start date by walking back from today, accounting for both events and freezes
    let startDate = getStartOfDay(currentDate, timezone);

    // Apply leeway offset if applicable
    if (configuration.leeway_hours > 0) {
      const hoursSinceMidnight = getHoursBetween(startDate, currentDate);

      if (hoursSinceMidnight <= configuration.leeway_hours) {
        startDate = new Date(startDate);
        startDate.setDate(startDate.getDate() - 1);
      }
    }

    // Walk back (currentStreak - 1) days to find the start
    if (currentStreak > 1) {
      startDate = new Date(startDate);
      startDate.setDate(startDate.getDate() - (currentStreak - 1));
    }

    streakStartDate = Timestamp.fromDate(startDate);
  }

  // COUNT REMAINING FREEZES
  const freezesRemaining = availableFreezes.length;

  // GET RECENT EVENTS (last 60 days, accounting for leeway)
  const recentEvents = getRecentEvents(events, 60, timezone, configuration.leeway_hours, currentDate);

  const streak: CurrentStreakData = {
    streak_id: configuration.streak_id,
    user_id: userId,
    current_streak: currentStreak,
    longest_streak: longestStreak,
    date_last_event: lastEvent.date_created,
    last_event_timezone: lastEvent.timezone,
    date_streak_start: streakStartDate,
    total_events: events.length,
    freezes_available: availableFreezes,
    freezes_available_count: freezesRemaining,
    date_created: events.length > 0 ? events[0].date_created : undefined,
    date_updated: Timestamp.fromDate(currentDate),
    events_required_per_day: configuration.events_required_per_day,
    today_event_count: todayEventCount,
    recent_events: recentEvents
  };

  return { streak, freezeConsumptions };
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
 * Get number of days between two dates
 */
function getDaysBetween(startDate: Date, endDate: Date, timezone: string): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const start = getStartOfDay(startDate, timezone);
  const end = getStartOfDay(endDate, timezone);
  return Math.round((end.getTime() - start.getTime()) / msPerDay);
}

/**
 * Get number of hours between two dates
 */
function getHoursBetween(startDate: Date, endDate: Date): number {
  const msPerHour = 60 * 60 * 1000;
  return Math.floor((endDate.getTime() - startDate.getTime()) / msPerHour);
}

/**
 * Check if a freeze is available
 */
function isAvailable(freeze: StreakFreeze, currentDate: Date): boolean {
  // Check if used
  if (freeze.date_used) {
    return false;
  }

  // Check if expired
  if (freeze.date_expires) {
    return currentDate <= freeze.date_expires.toDate();
  }

  return true;
}

/**
 * Generate a UUID (simple implementation)
 */
function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// ============================================================================
// MARK: - Main Cloud Function
// ============================================================================

/**
 * calculateStreak - Firebase Callable Function (2nd Gen)
 *
 * Performs server-side streak calculation EXACTLY as client-side StreakCalculator
 *
 * Mirrors: StreakManager.calculateStreakAsync() (lines 276-341)
 */
export const calculateStreak = onCall<CalculateStreakRequest>(
  async (request) => {
    const { userId, streakKey, configuration, rootCollectionName = 'swiftful_streaks', timezone: requestTimezone } = request.data;

    // Validate input
    if (!userId || !streakKey || !configuration) {
      throw new HttpsError(
        'invalid-argument',
        'Missing required parameters: userId, streakKey, or configuration'
      );
    }

    try {
      // Get all events and freezes (same as client-side lines 289-290)
      const events = await getAllEvents(rootCollectionName, userId, streakKey);
      const freezes = await getAllStreakFreezes(rootCollectionName, userId, streakKey);

      // Calculate streak (same as client-side lines 292-297)
      const currentDate = new Date();
      // Use passed timezone, or fallback to last event's timezone, or fallback to UTC
      const timezone = requestTimezone
        || (events.length > 0 ? events[events.length - 1].timezone : null)
        || 'UTC';

      const { streak: calculatedStreak, freezeConsumptions } = calculateStreak(
        events,
        freezes,
        configuration,
        userId,
        currentDate,
        timezone
      );

      // Auto-consume freezes if needed (same as client-side lines 300-336)
      if (freezeConsumptions.length > 0) {
        for (const consumption of freezeConsumptions) {
          // Create freeze event (same as client-side lines 303-309)
          const freezeEvent: StreakEvent = {
            id: generateUUID(),
            date_created: Timestamp.fromDate(consumption.date),
            timezone: calculatedStreak.last_event_timezone ?? timezone,
            is_freeze: true,
            freeze_id: consumption.freezeId,
            metadata: {}
          };
          await addEvent(rootCollectionName, userId, streakKey, freezeEvent);

          // Mark freeze as used (same as client-side line 313)
          await useStreakFreeze(rootCollectionName, userId, streakKey, consumption.freezeId);
        }

        // Recalculate streak after adding freeze events (same as client-side lines 318-327)
        const updatedEvents = await getAllEvents(rootCollectionName, userId, streakKey);
        const updatedFreezes = await getAllStreakFreezes(rootCollectionName, userId, streakKey);

        const { streak: finalStreak } = calculateStreak(
          updatedEvents,
          updatedFreezes,
          configuration,
          userId,
          currentDate,
          timezone
        );

        // Update Firestore (same as client-side line 330)
        await updateCurrentStreak(rootCollectionName, userId, streakKey, finalStreak);
      } else {
        // No freeze consumption needed (same as client-side lines 333-335)
        await updateCurrentStreak(rootCollectionName, userId, streakKey, calculatedStreak);
      }

      // Success - no return value needed (same as client-side)
      return { success: true };

    } catch (error) {
      // Throw errors the same places the client-side calculation throws errors
      throw new HttpsError(
        'internal',
        `Failed to calculate streak: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }
);
