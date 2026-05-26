import { ActivityType } from './dto/create-activity.dto';

export function scoreForActivity(type: ActivityType, payload?: Record<string, unknown>) {
  switch (type) {
    case 'taskCompleted':
      return { points: 10, reason: 'completed task' };
    case 'subTaskCompleted':
      return { points: 3, reason: 'completed sub task' };
    case 'studyLogCreated':
      return { points: 5, reason: 'created study log' };
    case 'noteCreated':
      return { points: 3, reason: 'created study note' };
    case 'flashcardBatchCreated': {
      const cardCount = Number(payload?.cardCount ?? 1);
      return {
        points: Math.min(20, Math.max(2, Math.floor(cardCount) * 2)),
        reason: 'created flashcards',
      };
    }
    case 'timerCompleted': {
      const minutes = Number(payload?.durationMinutes ?? 25);
      return {
        points: Math.max(0, Math.floor(minutes / 25) * 5),
        reason: 'completed focus timer',
      };
    }
    case 'momentShared':
      return { points: 1, reason: 'learning moment shared' };
    case 'dailyStreak':
      return { points: 2, reason: 'daily streak' };
    case 'challengeEvidence':
      return { points: 6, reason: 'challenge evidence submitted' };
    case 'evidencePackageShared':
      return { points: 8, reason: 'evidence package shared' };
    case 'locationCheckIn':
      return { points: 2, reason: 'location check-in' };
    case 'voiceReview':
      return { points: 4, reason: 'voice review' };
    case 'aiLoopApplied':
      return { points: 5, reason: 'AI loop applied' };
    case 'translatedMoment':
      return { points: 1, reason: 'bilingual moment generated' };
    case 'imageGenerated':
      return { points: 3, reason: 'learning cover generated' };
  }
}
