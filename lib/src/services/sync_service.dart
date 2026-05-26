import 'dart:convert';

import '../models/ai_flash_card.dart';
import '../models/ai_action_record.dart';
import '../models/achievement.dart';
import '../models/learning_moment.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_task_item.dart';
import '../models/trash_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_report_item.dart';
import 'api_client.dart';

class SyncItemPayload {
  const SyncItemPayload({
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    required this.updatedAt,
    this.deletedAt,
  });

  final String entityType;
  final String entityId;
  final Map<String, dynamic> payloadJson;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class PullResult {
  const PullResult({required this.items, required this.nextCursor});

  final List<SyncItemPayload> items;
  final String nextCursor;
}

class SyncService {
  SyncService({ApiClient? apiClient}) : _api = apiClient;

  ApiClient? _api;

  ApiClient get api {
    final client = _api;
    if (client == null) {
      throw const ApiException('尚未初始化后端连接');
    }
    return client;
  }

  void attach(ApiClient client) {
    _api = client;
  }

  Future<void> push(List<SyncItemPayload> items) async {
    if (items.isEmpty) return;
    await api.post('/sync/push', body: {
      'items': items
          .map((item) => {
                'entityType': item.entityType,
                'entityId': item.entityId,
                'payloadJson': item.payloadJson,
                'updatedAt': item.updatedAt.toUtc().toIso8601String(),
                'deletedAt': item.deletedAt?.toUtc().toIso8601String(),
              })
          .toList(),
    });
  }

  Future<PullResult> pull({String? cursor}) async {
    final data = await api.getJson(
      '/sync/pull',
      query: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final nextCursor =
        (data['nextCursor'] as String?) ?? cursor ?? DateTime.now().toUtc().toIso8601String();
    final rawItems = data['items'];
    final items = <SyncItemPayload>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final payload = map['payloadJson'];
        items.add(SyncItemPayload(
          entityType: (map['entityType'] as String?) ?? '',
          entityId: (map['entityId'] as String?) ?? '',
          payloadJson: payload is Map<String, dynamic>
              ? payload
              : payload is Map
                  ? payload.cast<String, dynamic>()
                  : <String, dynamic>{},
          updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? '') ??
              DateTime.now().toUtc(),
          deletedAt: map['deletedAt'] != null
              ? DateTime.tryParse(map['deletedAt'] as String)
              : null,
        ));
      }
    }
    return PullResult(items: items, nextCursor: nextCursor);
  }

  List<SyncItemPayload> buildLocalPayloads({
    required List<StudyTaskItem> tasks,
    required List<StudyLogItem> logs,
    required List<StudyNote> notes,
    required List<AiFlashCard> cards,
    required List<String> courses,
    required List<WeeklyReportItem> reports,
    required UserProfile profile,
    required List<TrashItem> trashItems,
    required List<AiActionRecord> actionRecords,
    required List<LearningMoment> moments,
    required GamificationState gamificationState,
    DateTime? deletedAt,
  }) {
    final now = DateTime.now();
    final items = <SyncItemPayload>[
      for (final task in tasks)
        SyncItemPayload(
          entityType: 'study_task',
          entityId: task.id,
          payloadJson: task.toJson(),
          updatedAt: task.updatedAt,
        ),
      for (final log in logs)
        SyncItemPayload(
          entityType: 'study_log',
          entityId: log.id,
          payloadJson: log.toJson(),
          updatedAt: log.createdAt,
        ),
      for (final note in notes)
        SyncItemPayload(
          entityType: 'study_note',
          entityId: note.id,
          payloadJson: note.toJson(),
          updatedAt: note.updatedAt,
        ),
      for (final card in cards)
        SyncItemPayload(
          entityType: 'flash_card',
          entityId: card.id,
          payloadJson: card.toJson(),
          updatedAt: card.createdAt,
        ),
      for (final report in reports)
        SyncItemPayload(
          entityType: 'weekly_report',
          entityId: report.id,
          payloadJson: report.toJson(),
          updatedAt: report.createdAt,
        ),
      for (final trash in trashItems)
        SyncItemPayload(
          entityType: 'trash_item',
          entityId: trash.id,
          payloadJson: trash.toJson(),
          updatedAt: trash.deletedAt,
        ),
      for (final record in actionRecords)
        SyncItemPayload(
          entityType: 'ai_action_record',
          entityId: record.id,
          payloadJson: record.toJson(),
          updatedAt: record.createdAt,
        ),
      for (final moment in moments)
        SyncItemPayload(
          entityType: 'learning_moment',
          entityId: moment.id,
          payloadJson: moment.toJson(),
          updatedAt: moment.createdAt,
        ),
      SyncItemPayload(
        entityType: 'course_catalog',
        entityId: 'default',
        payloadJson: {'courses': courses},
        updatedAt: now,
      ),
      SyncItemPayload(
        entityType: 'user_profile',
        entityId: 'me',
        payloadJson: profile.toJson(),
        updatedAt: now,
      ),
      SyncItemPayload(
        entityType: 'gamification_state',
        entityId: 'me',
        payloadJson: gamificationState.toJson(),
        updatedAt: now,
      ),
    ];
    return items;
  }

  SyncItemPayload buildDeletedPayload({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payloadJson,
    DateTime? deletedAt,
  }) {
    return SyncItemPayload(
      entityType: entityType,
      entityId: entityId,
      payloadJson: payloadJson,
      updatedAt: deletedAt ?? DateTime.now(),
      deletedAt: deletedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> parsePayload(SyncItemPayload item) {
    final raw = item.payloadJson;
    if (raw.isEmpty) return {};
    return raw;
  }
}
