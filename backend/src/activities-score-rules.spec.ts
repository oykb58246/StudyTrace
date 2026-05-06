import { scoreForActivity } from './modules/activities/score-rules';

describe('scoreForActivity', () => {
  it('scores fixed activity types', () => {
    expect(scoreForActivity('taskCompleted').points).toBe(10);
    expect(scoreForActivity('subTaskCompleted').points).toBe(3);
    expect(scoreForActivity('studyLogCreated').points).toBe(5);
    expect(scoreForActivity('dailyStreak').points).toBe(2);
  });

  it('scores tomato timer by each 25-minute block', () => {
    expect(scoreForActivity('timerCompleted', { durationMinutes: 24 }).points).toBe(0);
    expect(scoreForActivity('timerCompleted', { durationMinutes: 25 }).points).toBe(5);
    expect(scoreForActivity('timerCompleted', { durationMinutes: 60 }).points).toBe(10);
  });
});
