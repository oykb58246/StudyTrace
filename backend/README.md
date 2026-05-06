# StudyTrace Backend

Self-hosted NestJS backend for StudyTrace: auth, cloud sync, AI proxy, invitation-only study groups, activities, and leaderboards.

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
docker compose up --build
```

## API Surface

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `GET /me`
- `PATCH /me/profile`
- `POST /sync/push`
- `GET /sync/pull?cursor=...`
- `GET /sync/export`
- `POST /groups`
- `POST /groups/join`
- `GET /groups`
- `GET /groups/:id`
- `GET /groups/:id/members`
- `GET /groups/:id/activities`
- `DELETE /groups/:id/membership`
- `POST /activities`
- `GET /activities/mine`
- `GET /leaderboards/me`
- `GET /leaderboards/groups/:id?range=week|month`
- `POST /ai/study-log`
- `POST /ai/task-plan`
- `POST /ai/weekly-analysis`
- `POST /ai/risk-warnings`
- `POST /ai/flash-cards`
- `POST /ai/chat`
- `POST /ai/chat/stream`

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

Conflict rule v1: newer `updatedAt` wins. Deletes are soft deletes through `deletedAt`.
