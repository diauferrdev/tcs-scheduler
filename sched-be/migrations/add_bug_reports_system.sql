-- Migration: Add Bug Reports System
-- Description: Adds bug tracking with comments, likes, and attachments
-- Author: Claude Code
-- Date: 2025-10-21

-- Step 1: Create Enums
CREATE TYPE "Platform" AS ENUM ('WINDOWS', 'LINUX', 'MACOS', 'ANDROID', 'IOS', 'WEB');
CREATE TYPE "BugStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');

-- Step 2: Add new notification types
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'BUG_REPORT_CREATED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'BUG_REPORT_RESOLVED';

-- Step 3: Create BugReport table
CREATE TABLE "BugReport" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "deviceInfo" JSONB,
    "status" "BugStatus" NOT NULL DEFAULT 'OPEN',
    "likeCount" INTEGER NOT NULL DEFAULT 0,
    "reportedById" TEXT NOT NULL,
    "resolvedById" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "resolutionNotes" TEXT,
    "closedById" TEXT,
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BugReport_pkey" PRIMARY KEY ("id")
);

-- Step 4: Create BugAttachment table
CREATE TABLE "BugAttachment" (
    "id" TEXT NOT NULL,
    "bugReportId" TEXT NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "fileType" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BugAttachment_pkey" PRIMARY KEY ("id")
);

-- Step 5: Create BugComment table
CREATE TABLE "BugComment" (
    "id" TEXT NOT NULL,
    "bugReportId" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BugComment_pkey" PRIMARY KEY ("id")
);

-- Step 6: Create BugLike table
CREATE TABLE "BugLike" (
    "id" TEXT NOT NULL,
    "bugReportId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BugLike_pkey" PRIMARY KEY ("id")
);

-- Step 7: Create indexes for BugReport
CREATE INDEX "BugReport_status_idx" ON "BugReport"("status");
CREATE INDEX "BugReport_platform_idx" ON "BugReport"("platform");
CREATE INDEX "BugReport_reportedById_idx" ON "BugReport"("reportedById");
CREATE INDEX "BugReport_likeCount_idx" ON "BugReport"("likeCount");
CREATE INDEX "BugReport_createdAt_idx" ON "BugReport"("createdAt");

-- Step 8: Create indexes for BugAttachment
CREATE INDEX "BugAttachment_bugReportId_idx" ON "BugAttachment"("bugReportId");

-- Step 9: Create indexes for BugComment
CREATE INDEX "BugComment_bugReportId_idx" ON "BugComment"("bugReportId");
CREATE INDEX "BugComment_userId_idx" ON "BugComment"("userId");
CREATE INDEX "BugComment_createdAt_idx" ON "BugComment"("createdAt");

-- Step 10: Create indexes for BugLike
CREATE INDEX "BugLike_bugReportId_idx" ON "BugLike"("bugReportId");
CREATE INDEX "BugLike_userId_idx" ON "BugLike"("userId");
CREATE UNIQUE INDEX "BugLike_bugReportId_userId_key" ON "BugLike"("bugReportId", "userId");

-- Step 11: Add foreign keys for BugReport
ALTER TABLE "BugReport" ADD CONSTRAINT "BugReport_reportedById_fkey" FOREIGN KEY ("reportedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "BugReport" ADD CONSTRAINT "BugReport_resolvedById_fkey" FOREIGN KEY ("resolvedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "BugReport" ADD CONSTRAINT "BugReport_closedById_fkey" FOREIGN KEY ("closedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Step 12: Add foreign keys for BugAttachment
ALTER TABLE "BugAttachment" ADD CONSTRAINT "BugAttachment_bugReportId_fkey" FOREIGN KEY ("bugReportId") REFERENCES "BugReport"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Step 13: Add foreign keys for BugComment
ALTER TABLE "BugComment" ADD CONSTRAINT "BugComment_bugReportId_fkey" FOREIGN KEY ("bugReportId") REFERENCES "BugReport"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "BugComment" ADD CONSTRAINT "BugComment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Step 14: Add foreign keys for BugLike
ALTER TABLE "BugLike" ADD CONSTRAINT "BugLike_bugReportId_fkey" FOREIGN KEY ("bugReportId") REFERENCES "BugReport"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "BugLike" ADD CONSTRAINT "BugLike_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
