CREATE TABLE "GroupChallenge" (
  "id" TEXT NOT NULL,
  "groupId" TEXT NOT NULL,
  "createdById" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT,
  "planJson" JSONB NOT NULL,
  "scoringJson" JSONB,
  "coverImageUrl" TEXT,
  "status" TEXT NOT NULL DEFAULT 'active',
  "startsAt" TIMESTAMP(3),
  "endsAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "GroupChallenge_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ChallengeParticipation" (
  "id" TEXT NOT NULL,
  "challengeId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "progress" INTEGER NOT NULL DEFAULT 0,
  "evidenceCount" INTEGER NOT NULL DEFAULT 0,
  "completedAt" TIMESTAMP(3),
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ChallengeParticipation_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ChallengeEvidence" (
  "id" TEXT NOT NULL,
  "challengeId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "evidenceType" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "summary" TEXT,
  "sourceType" TEXT,
  "sourceId" TEXT,
  "payloadJson" JSONB,
  "happenedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ChallengeEvidence_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "EvidencePackage" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "groupId" TEXT,
  "title" TEXT NOT NULL,
  "courseName" TEXT,
  "description" TEXT,
  "sourceRefsJson" JSONB NOT NULL,
  "metricsJson" JSONB NOT NULL,
  "coverImageUrl" TEXT,
  "visibility" TEXT NOT NULL DEFAULT 'private',
  "featured" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "EvidencePackage_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LocationCheckIn" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "groupId" TEXT,
  "title" TEXT NOT NULL,
  "address" TEXT,
  "latitude" DOUBLE PRECISION,
  "longitude" DOUBLE PRECISION,
  "poiPayloadJson" JSONB,
  "visibility" TEXT NOT NULL DEFAULT 'private',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "LocationCheckIn_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MemoryChunk" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "sourceType" TEXT NOT NULL,
  "sourceId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "embeddingJson" JSONB,
  "metadataJson" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "MemoryChunk_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "GroupChallenge_groupId_status_idx" ON "GroupChallenge"("groupId", "status");
CREATE INDEX "GroupChallenge_createdById_idx" ON "GroupChallenge"("createdById");
CREATE UNIQUE INDEX "ChallengeParticipation_challengeId_userId_key" ON "ChallengeParticipation"("challengeId", "userId");
CREATE INDEX "ChallengeParticipation_userId_idx" ON "ChallengeParticipation"("userId");
CREATE INDEX "ChallengeEvidence_challengeId_happenedAt_idx" ON "ChallengeEvidence"("challengeId", "happenedAt");
CREATE INDEX "ChallengeEvidence_userId_happenedAt_idx" ON "ChallengeEvidence"("userId", "happenedAt");
CREATE INDEX "ChallengeEvidence_sourceType_sourceId_idx" ON "ChallengeEvidence"("sourceType", "sourceId");
CREATE INDEX "EvidencePackage_userId_createdAt_idx" ON "EvidencePackage"("userId", "createdAt");
CREATE INDEX "EvidencePackage_groupId_featured_idx" ON "EvidencePackage"("groupId", "featured");
CREATE INDEX "LocationCheckIn_userId_createdAt_idx" ON "LocationCheckIn"("userId", "createdAt");
CREATE INDEX "LocationCheckIn_groupId_createdAt_idx" ON "LocationCheckIn"("groupId", "createdAt");
CREATE INDEX "MemoryChunk_userId_sourceType_idx" ON "MemoryChunk"("userId", "sourceType");
CREATE INDEX "MemoryChunk_sourceType_sourceId_idx" ON "MemoryChunk"("sourceType", "sourceId");

ALTER TABLE "GroupChallenge" ADD CONSTRAINT "GroupChallenge_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "GroupChallenge" ADD CONSTRAINT "GroupChallenge_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChallengeParticipation" ADD CONSTRAINT "ChallengeParticipation_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "GroupChallenge"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChallengeParticipation" ADD CONSTRAINT "ChallengeParticipation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChallengeEvidence" ADD CONSTRAINT "ChallengeEvidence_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "GroupChallenge"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ChallengeEvidence" ADD CONSTRAINT "ChallengeEvidence_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EvidencePackage" ADD CONSTRAINT "EvidencePackage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EvidencePackage" ADD CONSTRAINT "EvidencePackage_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "LocationCheckIn" ADD CONSTRAINT "LocationCheckIn_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LocationCheckIn" ADD CONSTRAINT "LocationCheckIn_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "Group"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "MemoryChunk" ADD CONSTRAINT "MemoryChunk_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
