# StudyTrace Backend

NestJS backend for StudyTrace. It provides authentication, user profiles, offline-first cloud sync, AI proxy capabilities, learning groups, learning moments, community evidence, leaderboards, and usage records.

The current database provider is MySQL through Prisma.

## Quick Start

```bash
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run start:dev
```

Docker:

```bash
docker compose up --build -d
```

## Main Modules

* `HealthModule`: service health endpoint.
* `AuthModule`: registration, login, refresh, logout, and account removal.
* `UsersModule`: current user profile and preferences.
* `SyncModule`: generic entity push/pull, export, soft delete, and last-write-wins conflict handling.
* `GroupsModule`: invitation-only study groups and membership.
* `MomentsModule`: learning moments, visibility, likes, and comments.
* `ActivitiesModule`: activity feed items and score events.
* `LeaderboardsModule`: personal and group ranking metrics.
* `CommunityEvidenceModule`: group challenges, challenge evidence, evidence packages, and location check-ins.
* `AiModule`: hosted AI access for learning generation, chat, OCR, translation, images, videos, speech transcription, semantic retrieval, memory indexing, POI, reverse geocoding, capability badges, and usage summaries.

## API Surface

### Health

* `GET /health`

### Auth

* `POST /auth/register`
* `POST /auth/login`
* `POST /auth/refresh`
* `POST /auth/logout`
* `POST /auth/delete-account`

### Users

* `GET /me`
* `PATCH /me/profile`
* `DELETE /me`

### Sync

* `POST /sync/push`
* `GET /sync/pull?cursor=...`
* `GET /sync/export`

### Groups

* `POST /groups`
* `POST /groups/join`
* `GET /groups`
* `GET /groups/:id`
* `GET /groups/:id/members`
* `GET /groups/:id/activities`
* `DELETE /groups/:id/membership`

### Learning Moments

* `POST /moments`
* `GET /moments/feed`
* `PATCH /moments/:id/visibility`
* `DELETE /moments/:id`
* `POST /moments/:id/likes/me`
* `DELETE /moments/:id/likes/me`
* `POST /moments/:id/comments`
* `DELETE /moments/:id/comments/:commentId`

### Activities And Leaderboards

* `POST /activities`
* `GET /activities/mine`
* `GET /leaderboards/me`
* `GET /leaderboards/groups/:id?range=week|month&metric=...`

### Community Evidence

* `POST /groups/:id/challenges/ai-draft`
* `POST /groups/:id/challenges`
* `GET /groups/:id/challenges`
* `POST /groups/:id/challenges/:challengeId/join`
* `POST /groups/:id/challenges/:challengeId/evidence`
* `GET /groups/:id/challenges/:challengeId/leaderboard`
* `POST /evidence-packages`
* `GET /evidence-packages/mine`
* `GET /groups/:id/evidence-packages`
* `PATCH /evidence-packages/:id`
* `POST /locations/check-ins`
* `GET /locations/check-ins/mine`

### AI

* `POST /ai/study-log`
* `POST /ai/task-plan`
* `POST /ai/weekly-plan`
* `POST /ai/learning-loop`
* `POST /ai/weekly-analysis`
* `POST /ai/risk-warnings`
* `POST /ai/flash-cards`
* `POST /ai/grade-flashcard`
* `POST /ai/rewrite`
* `POST /ai/ocr`
* `POST /ai/query-rewrite`
* `POST /ai/rerank`
* `POST /ai/translate`
* `POST /ai/images/tasks`
* `POST /ai/images/tasks/status`
* `POST /ai/videos/tasks`
* `POST /ai/videos/tasks/status`
* `POST /ai/speech/transcribe`
* `POST /ai/embeddings`
* `POST /ai/memory/index`
* `POST /ai/memory/search`
* `POST /ai/poi-search`
* `POST /ai/reverse-geocode`
* `GET /ai/capability-badges`
* `POST /ai/chat`
* `POST /ai/chat/stream`
* `GET /ai/usage/today`

## Sync Contract

`POST /sync/push` accepts client-owned IDs and JSON payloads:

```json
{
  "items": [
    {
      "entityType": "study_task",
      "entityId": "local-task-id",
      "payloadJson": {},
      "updatedAt": "2026-05-06T00:00:00.000Z",
      "deletedAt": null
    }
  ]
}
```

Conflict rule v1: newer `updatedAt` wins. Deletes are represented by `deletedAt`.

## AI Boundary

Flutter calls StudyTrace backend endpoints instead of calling vivo/BlueLM services directly. Provider keys live in backend environment variables such as `BLUEHEART_*` and `VIVO_*`.

Current speech support is based on recorded audio file transcription and local playback on the client. Real-time streaming speech and provider-hosted TTS should be handled as separate platform work.
