/**
 * Firebase Cloud Functions for SwiftfulGamification
 *
 * This file exports the cloud functions for server-side gamification calculations.
 * These functions mirror the client-side Swift implementations exactly.
 */

import { initializeApp } from 'firebase-admin/app';

// Initialize Firebase Admin (only once for all functions)
initializeApp();

// Export the streak calculation function
export { calculateStreak } from './calculateStreak';

// Export the experience points calculation function
export { calculateExperiencePoints } from './calculateExperiencePoints';
