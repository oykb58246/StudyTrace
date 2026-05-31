CREATE TABLE `LearningMoment` (
  `id` VARCHAR(191) NOT NULL,
  `userId` VARCHAR(191) NOT NULL,
  `content` TEXT NOT NULL,
  `courseName` VARCHAR(191) NULL,
  `imagePathsJson` JSON NULL,
  `visibility` VARCHAR(191) NOT NULL DEFAULT 'private',
  `allowedGroupIds` JSON NULL,
  `deniedGroupIds` JSON NULL,
  `sourceType` VARCHAR(191) NULL,
  `sourceId` VARCHAR(191) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `LearningMomentLike` (
  `id` VARCHAR(191) NOT NULL,
  `momentId` VARCHAR(191) NOT NULL,
  `userId` VARCHAR(191) NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `LearningMomentComment` (
  `id` VARCHAR(191) NOT NULL,
  `momentId` VARCHAR(191) NOT NULL,
  `userId` VARCHAR(191) NOT NULL,
  `content` TEXT NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE INDEX `LearningMoment_userId_createdAt_idx` ON `LearningMoment`(`userId`, `createdAt`);
CREATE INDEX `LearningMoment_visibility_createdAt_idx` ON `LearningMoment`(`visibility`, `createdAt`);
CREATE UNIQUE INDEX `LearningMomentLike_momentId_userId_key` ON `LearningMomentLike`(`momentId`, `userId`);
CREATE INDEX `LearningMomentLike_userId_idx` ON `LearningMomentLike`(`userId`);
CREATE INDEX `LearningMomentComment_momentId_createdAt_idx` ON `LearningMomentComment`(`momentId`, `createdAt`);
CREATE INDEX `LearningMomentComment_userId_idx` ON `LearningMomentComment`(`userId`);

ALTER TABLE `LearningMoment` ADD CONSTRAINT `LearningMoment_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `LearningMomentLike` ADD CONSTRAINT `LearningMomentLike_momentId_fkey` FOREIGN KEY (`momentId`) REFERENCES `LearningMoment`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `LearningMomentLike` ADD CONSTRAINT `LearningMomentLike_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `LearningMomentComment` ADD CONSTRAINT `LearningMomentComment_momentId_fkey` FOREIGN KEY (`momentId`) REFERENCES `LearningMoment`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `LearningMomentComment` ADD CONSTRAINT `LearningMomentComment_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
