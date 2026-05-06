import { ActivityType } from './dto/create-activity.dto';

export function scoreForActivity(type: ActivityType, payload?: Record<string, unknown>) {
  switch (type) {
    case 'taskCompleted':
      return { points: 10, reason: '完成任务' };
    case 'subTaskCompleted':
      return { points: 3, reason: '完成子任务' };
    case 'studyLogCreated':
      return { points: 5, reason: '新增学习日志' };
    case 'timerCompleted': {
      const minutes = Number(payload?.durationMinutes ?? 25);
      return {
        points: Math.max(0, Math.floor(minutes / 25) * 5),
        reason: '完成番茄钟',
      };
    }
    case 'dailyStreak':
      return { points: 2, reason: '连续打卡' };
  }
}
