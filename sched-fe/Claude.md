# TCS PacePort Scheduler - Complete Project Definition Document

## Executive Summary
Enterprise-grade scheduling system for TCS PacePort São Paulo office visits with role-based access control, automated invitations, and seamless booking management. Built with Bun, PostgreSQL, and modern web technologies.

---

## Tech Stack

### Frontend (Port 3000)
- **Runtime/Package Manager**: Bun
- **Bundler**: RSBuild (pre-configured) - **Always check https://rsbuild.dev/guide when implementing RSBuild-specific features**
- **Framework**: React 18+ with TypeScript
- **Styling**: TailwindCSS v3
- **State Management**: TanStack Query v5
- **Animations**: Framer Motion
- **Forms**: React Hook Form
- **Validation**: Zod
- **Date Handling**: date-fns
- **HTTP Client**: Axios with interceptors
- **PWA**: Workbox via RSBuild plugin
- **UI Components**: Pre-installed shadcn/ui components

### Backend (Port 7777)
- **Runtime**: Bun
- **Framework**: Hono - **Check https://hono.dev when implementing routes/middleware**
- **ORM**: Prisma - **Check https://prisma.io/docs for schema/queries**
- **Database**: PostgreSQL 15+
- **Auth**: Lucia Auth - **Check https://lucia-auth.com for auth implementation**
- **Validation**: Zod
- **Email**: Resend (preferred) or Nodemailer
- **Environment**: dotenv

### Database
- **Production**: PostgreSQL 15+
- **Connection Pooling**: Native Prisma pooling
- **Migrations**: Prisma Migrate

---

## Pre-installed UI Components

The frontend already has these shadcn/ui components available in `src/components/ui/`:

```
alert-dialog.tsx    calendar.tsx       drawer.tsx          label.tsx           separator.tsx      toggle.tsx
alert.tsx           card.tsx           dropdown-menu.tsx   menubar.tsx         sheet.tsx          tooltip.tsx
aspect-ratio.tsx    carousel.tsx       empty.tsx           navigation-menu.tsx sidebar.tsx        
avatar.tsx          checkbox.tsx       field.tsx           pagination.tsx      skeleton.tsx
badge.tsx           collapsible.tsx    hover-card.tsx      popover.tsx         slider.tsx
breadcrumb.tsx      command.tsx        input-group.tsx     progress.tsx        sonner.tsx
button-group.tsx    context-menu.tsx   input-otp.tsx       radio-group.tsx     spinner.tsx
button.tsx          dialog.tsx         input.tsx           resizable.tsx       switch.tsx
                                       item.tsx            scroll-area.tsx     table.tsx
                                       kbd.tsx             select.tsx          tabs.tsx
                                                                              textarea.tsx
                                                                              toggle-group.tsx
```

**Use these components directly - no need to install or create new ones.**

---

## Database Schema

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum UserRole {
  ADMIN
  MANAGER
  GUEST
}

enum VisitDuration {
  THREE_HOURS
  SIX_HOURS
}

enum BookingStatus {
  PENDING
  CONFIRMED
  CANCELLED
}

model User {
  id            String    @id @default(cuid())
  email         String    @unique
  passwordHash  String
  name          String
  role          UserRole  @default(MANAGER)
  isActive      Boolean   @default(true)
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
  
  sessions         Session[]
  bookingsCreated  Booking[] @relation("CreatedBy")
  invitationsCreated Invitation[] @relation("InvitationCreator")
  
  @@index([email])
  @@index([role])
}

model Session {
  id        String   @id
  userId    String
  expiresAt DateTime
  createdAt DateTime @default(now())
  
  user      User     @relation(references: [id], fields: [userId], onDelete: Cascade)
  
  @@index([userId])
}

model Booking {
  id              String         @id @default(cuid())
  date            DateTime       @db.Date
  startTime       String         // "09:00" or "14:00"
  duration        VisitDuration
  status          BookingStatus  @default(PENDING)
  
  // Company Information
  companyName     String
  companySector   String         // Tech, Finance, Healthcare, etc.
  companyVertical String         // Vertical or Horizontal classification
  companySize     String?        // Small, Medium, Large, Enterprise
  
  // Contact Information
  contactName     String
  contactEmail    String
  contactPhone    String?
  contactPosition String?
  
  // Business Information
  interestArea    String         // AI, Cloud, Digital Transformation, etc.
  expectedAttendees Int          @default(1)
  businessGoal    String?        // What they want to achieve
  additionalNotes String?        @db.Text
  
  // Metadata
  invitationId    String?        @unique
  invitation      Invitation?    @relation(fields: [invitationId], references: [id])
  createdById     String?
  createdBy       User?          @relation("CreatedBy", fields: [createdById], references: [id])
  
  createdAt       DateTime       @default(now())
  updatedAt       DateTime       @updatedAt
  
  @@index([date])
  @@index([status])
  @@index([createdById])
}

model Invitation {
  id              String    @id @default(cuid())
  token           String    @unique @default(cuid())
  email           String?
  expiresAt       DateTime
  usedAt          DateTime?
  isActive        Boolean   @default(true)
  
  createdById     String
  createdBy       User      @relation("InvitationCreator", fields: [createdById], references: [id])
  
  booking         Booking?
  
  createdAt       DateTime  @default(now())
  
  @@index([token])
  @@index([createdById])
  @@index([expiresAt])
}
```

---

## Zod Validation Schemas

### Shared Types (types/index.ts)
```typescript
import { z } from 'zod';

// Enums
export const UserRoleSchema = z.enum(['ADMIN', 'MANAGER', 'GUEST']);
export const VisitDurationSchema = z.enum(['THREE_HOURS', 'SIX_HOURS']);
export const BookingStatusSchema = z.enum(['PENDING', 'CONFIRMED', 'CANCELLED']);

// Auth
export const LoginSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// Booking
export const BookingCreateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  duration: VisitDurationSchema,
  startTime: z.enum(['09:00', '14:00']),
  
  // Company Information
  companyName: z.string().min(2, 'Company name must be at least 2 characters'),
  companySector: z.string().min(1, 'Company sector is required'),
  companyVertical: z.string().min(1, 'Company vertical is required'),
  companySize: z.string().optional(),
  
  // Contact Information
  contactName: z.string().min(2, 'Contact name must be at least 2 characters'),
  contactEmail: z.string().email('Invalid email format'),
  contactPhone: z.string().optional(),
  contactPosition: z.string().optional(),
  
  // Business Information
  interestArea: z.string().min(1, 'Interest area is required'),
  expectedAttendees: z.number().int().min(1).max(50),
  businessGoal: z.string().max(500).optional(),
  additionalNotes: z.string().max(1000).optional(),
});

export const BookingGuestCreateSchema = BookingCreateSchema.extend({
  token: z.string().cuid(),
});

export const BookingUpdateSchema = BookingCreateSchema.partial().extend({
  status: BookingStatusSchema.optional(),
});

// Invitation
export const InvitationCreateSchema = z.object({
  email: z.string().email().optional(),
  expiresInDays: z.number().int().min(1).max(30).default(7),
});

export const InvitationSendEmailSchema = z.object({
  email: z.string().email('Invalid email format'),
  message: z.string().max(500).optional(),
});

// User
export const UserCreateSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  name: z.string().min(2, 'Name must be at least 2 characters'),
  role: UserRoleSchema.default('MANAGER'),
});

export const UserUpdateSchema = z.object({
  email: z.string().email().optional(),
  name: z.string().min(2).optional(),
  role: UserRoleSchema.optional(),
  isActive: z.boolean().optional(),
});

// Type inference
export type LoginInput = z.infer<typeof LoginSchema>;
export type BookingCreateInput = z.infer<typeof BookingCreateSchema>;
export type BookingGuestCreateInput = z.infer<typeof BookingGuestCreateSchema>;
export type BookingUpdateInput = z.infer<typeof BookingUpdateSchema>;
export type InvitationCreateInput = z.infer<typeof InvitationCreateSchema>;
export type InvitationSendEmailInput = z.infer<typeof InvitationSendEmailSchema>;
export type UserCreateInput = z.infer<typeof UserCreateSchema>;
export type UserUpdateInput = z.infer<typeof UserUpdateSchema>;
```

---

## User Roles & Access Matrix

| Feature | ADMIN | MANAGER | GUEST (with token) |
|---------|-------|---------|-------------------|
| Login to system | ✅ | ✅ | ❌ |
| View all bookings | ✅ | ✅ | ❌ |
| Create booking directly | ✅ | ✅ | ❌ |
| Create booking via token | ❌ | ❌ | ✅ |
| Cancel any booking | ✅ | ✅ (own only) | ❌ |
| Generate invitation links | ✅ | ✅ | ❌ |
| Send invitation emails | ✅ | ✅ | ❌ |
| Create/delete users | ✅ | ❌ | ❌ |
| View user list | ✅ | ❌ | ❌ |
| Access admin panel | ✅ | ❌ | ❌ |

---

## Core Features & Business Rules

### 1. Calendar System

#### Time Slots
- **3-hour visits**: 09:00-12:00 (morning) OR 14:00-17:00 (afternoon)
- **6-hour visits**: 09:00-17:00 (full day)

#### Availability Logic
```typescript
// A day can have:
// - Two 3h bookings (morning + afternoon)
// - One 6h booking (blocks entire day)
// - One 3h booking (leaves other slot available)

// Visual states:
// - Fully available: White background
// - Partially booked: Light gray (one 3h slot taken)
// - Fully booked: Dark gray (6h booking OR both 3h slots taken)
// - Past date: Disabled/grayed out
```

#### Navigation
- Monthly calendar view
- Previous/Next month buttons
- Jump to specific month
- Highlight current day
- Show bookings count per day

### 2. Booking Flow

#### For ADMIN/MANAGER (Authenticated)

**Direct Booking:**
1. Login → Dashboard
2. Navigate calendar to desired month
3. Click available date → Modal opens
4. Select duration (3h or 6h)
5. If 3h: Choose time slot (morning/afternoon)
6. Fill comprehensive form (validated by Zod)
7. Submit → Booking created
8. Confirmation shown

**Generate Invitation:**
1. Click "Generate Invitation" button
2. Optional: Enter recipient email
3. System generates unique token URL
4. Copy link or send via email
5. Link valid for 7 days (configurable)

#### For GUEST (Unauthenticated with token)

1. Receive email/link: `https://scheduler.tcs.com/book/{token}`
2. Token validated on page load
3. If invalid/expired: Show error message
4. If valid: Show calendar with available slots
5. Select date and time
6. Fill booking form (Zod validated)
7. Submit → Booking created, token consumed
8. Confirmation email sent automatically
9. Token becomes invalid (single use)

### 3. Validation with Zod

All forms use Zod schemas for validation on both frontend and backend:

**Frontend (React Hook Form + Zod):**
```typescript
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { BookingCreateSchema } from '@/types';

const form = useForm({
  resolver: zodResolver(BookingCreateSchema),
});
```

**Backend (Hono middleware):**
```typescript
import { zValidator } from '@hono/zod-validator';
import { BookingCreateSchema } from '../types';

app.post('/bookings', zValidator('json', BookingCreateSchema), async (c) => {
  const data = c.req.valid('json');
  // data is fully typed and validated
});
```

### 4. Email System

**Email Templates:**

1. **Invitation Email**
   - Subject: "You're invited to visit TCS PacePort São Paulo"
   - Contains booking link with token
   - Brief description of PacePort
   - Expiration notice (7 days)

2. **Booking Confirmation (for guest)**
   - Subject: "Your visit to TCS PacePort is confirmed"
   - Date, time, duration
   - Location details
   - Contact information
   - Calendar invite attachment (.ics)

3. **Booking Notification (for managers)**
   - Subject: "New booking created: {Company Name}"
   - All booking details
   - Link to view in system

---

## API Endpoints

### Authentication
```
POST   /api/auth/login
  Body: LoginSchema
  Returns: { user, sessionId }

POST   /api/auth/logout
  Headers: Cookie with session
  Returns: { success }

GET    /api/auth/me
  Headers: Cookie with session
  Returns: { user } or 401
```

### Bookings
```
GET    /api/bookings
  Query: ?month=2025-01&status=CONFIRMED
  Auth: Required (ADMIN/MANAGER)
  Returns: Booking[]

POST   /api/bookings
  Auth: Required (ADMIN/MANAGER)
  Body: BookingCreateSchema
  Returns: Booking

POST   /api/bookings/guest
  Body: BookingGuestCreateSchema (includes token)
  Returns: Booking

GET    /api/bookings/:id
  Auth: Required
  Returns: Booking

PATCH  /api/bookings/:id
  Auth: Required
  Body: BookingUpdateSchema
  Returns: Booking

DELETE /api/bookings/:id
  Auth: Required (ADMIN or creator)
  Returns: { success }

GET    /api/bookings/availability/:date
  Public endpoint
  Returns: { 
    date, 
    isFull, 
    availableSlots: ['morning', 'afternoon', 'full-day'],
    existingBookings: Booking[]
  }
```

### Invitations
```
POST   /api/invitations
  Auth: Required (ADMIN/MANAGER)
  Body: InvitationCreateSchema
  Returns: { token, link, expiresAt }

POST   /api/invitations/send
  Auth: Required
  Body: InvitationSendEmailSchema
  Returns: { success, invitation }

GET    /api/invitations/:token/validate
  Public
  Returns: { valid, expired, used, invitation }

GET    /api/invitations
  Auth: Required
  Returns: Invitation[]
```

### Users (Admin only)
```
POST   /api/users
  Auth: Required (ADMIN)
  Body: UserCreateSchema
  Returns: User

GET    /api/users
  Auth: Required (ADMIN)
  Returns: User[]

PATCH  /api/users/:id
  Auth: Required (ADMIN)
  Body: UserUpdateSchema
  Returns: User

DELETE /api/users/:id
  Auth: Required (ADMIN)
  Returns: { success }
```

---

## Frontend Structure

```
sched-fe/
├── public/
│   ├── manifest.json
│   ├── icons/
│   └── sw.js
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx (redirect based on auth)
│   │   ├── (auth)/
│   │   │   ├── login/
│   │   │   │   └── page.tsx
│   │   │   └── layout.tsx (centered, no nav)
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx (with sidebar/nav)
│   │   │   ├── calendar/
│   │   │   │   └── page.tsx
│   │   │   ├── bookings/
│   │   │   │   ├── page.tsx (list view)
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx (detail view)
│   │   │   ├── invitations/
│   │   │   │   └── page.tsx
│   │   │   └── admin/
│   │   │       ├── users/
│   │   │       │   └── page.tsx
│   │   │       └── settings/
│   │   │           └── page.tsx
│   │   └── (public)/
│   │       └── book/
│   │           └── [token]/
│   │               └── page.tsx (public booking)
│   ├── components/
│   │   ├── calendar/
│   │   │   ├── MonthView.tsx
│   │   │   ├── DayCell.tsx
│   │   │   ├── BookingModal.tsx
│   │   │   └── CalendarNavigation.tsx
│   │   ├── booking/
│   │   │   ├── BookingForm.tsx
│   │   │   ├── BookingCard.tsx
│   │   │   └── BookingFilters.tsx
│   │   ├── invitation/
│   │   │   ├── InvitationGenerator.tsx
│   │   │   └── InvitationList.tsx
│   │   ├── layout/
│   │   │   ├── Header.tsx
│   │   │   ├── Sidebar.tsx
│   │   │   └── Footer.tsx
│   │   └── ui/ (pre-installed components)
│   ├── lib/
│   │   ├── api.ts (axios instance)
│   │   ├── auth.ts (auth helpers)
│   │   ├── constants.ts
│   │   ├── utils.ts
│   │   └── hooks/
│   │       ├── useAuth.ts
│   │       ├── useBookings.ts
│   │       └── useInvitations.ts
│   ├── types/
│   │   └── index.ts (Zod schemas + types)
│   └── styles/
│       └── globals.css
├── rsbuild.config.ts
├── tailwind.config.js
├── tsconfig.json
└── package.json
```

---

## Backend Structure

```
sched-be/
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── src/
│   ├── index.ts (Hono app entry)
│   ├── routes/
│   │   ├── auth.ts
│   │   ├── bookings.ts
│   │   ├── invitations.ts
│   │   └── users.ts
│   ├── middleware/
│   │   ├── auth.ts (Lucia session validation)
│   │   ├── cors.ts
│   │   ├── validation.ts (Zod validation middleware)
│   │   └── errorHandler.ts
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── booking.service.ts
│   │   ├── email.service.ts
│   │   ├── invitation.service.ts
│   │   └── user.service.ts
│   ├── lib/
│   │   ├── lucia.ts (Lucia auth setup)
│   │   ├── prisma.ts (Prisma client)
│   │   └── email.ts (Email client setup)
│   ├── types/
│   │   └── index.ts (Zod schemas shared with frontend)
│   └── utils/
│       ├── password.ts
│       ├── token.ts
│       └── date.ts
├── .env
├── .env.example
├── tsconfig.json
└── package.json
```

---

## Design System - TCS Black & White Theme

### Color Palette
```css
:root {
  /* Base Colors */
  --color-white: #FFFFFF;
  --color-black: #000000;
  
  /* Grays */
  --color-gray-50: #FAFAFA;
  --color-gray-100: #F5F5F5;
  --color-gray-200: #E5E5E5;
  --color-gray-300: #D4D4D4;
  --color-gray-400: #A3A3A3;
  --color-gray-500: #737373;
  --color-gray-600: #525252;
  --color-gray-700: #404040;
  --color-gray-800: #262626;
  --color-gray-900: #171717;
  
  /* Semantic Colors */
  --color-bg: var(--color-white);
  --color-surface: var(--color-gray-50);
  --color-border: var(--color-gray-200);
  --color-text: var(--color-black);
  --color-text-secondary: var(--color-gray-600);
  --color-text-muted: var(--color-gray-400);
  
  /* Interactive */
  --color-primary: var(--color-black);
  --color-primary-hover: var(--color-gray-800);
  --color-secondary: var(--color-gray-100);
  --color-secondary-hover: var(--color-gray-200);
  
  /* States */
  --color-disabled: var(--color-gray-300);
  --color-success: var(--color-black);
  --color-error: var(--color-gray-800);
  
  /* Calendar States */
  --color-available: var(--color-white);
  --color-partial: var(--color-gray-100);
  --color-full: var(--color-gray-800);
  --color-past: var(--color-gray-200);
}
```

### Typography
```css
/* Font Family */
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;

/* Scale */
--font-xs: 0.75rem;    /* 12px */
--font-sm: 0.875rem;   /* 14px */
--font-base: 1rem;     /* 16px */
--font-lg: 1.125rem;   /* 18px */
--font-xl: 1.25rem;    /* 20px */
--font-2xl: 1.5rem;    /* 24px */
--font-3xl: 1.875rem;  /* 30px */
--font-4xl: 2.25rem;   /* 36px */

/* Weights */
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

### Spacing
```css
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-12: 3rem;     /* 48px */
--space-16: 4rem;     /* 64px */
```

### Component Styles

#### Buttons
```css
/* Primary Button */
.btn-primary {
  background: var(--color-black);
  color: var(--color-white);
  border: 1px solid var(--color-black);
  padding: 0.5rem 1rem;
  font-weight: 500;
  transition: all 150ms;
}
.btn-primary:hover {
  background: var(--color-gray-800);
}

/* Secondary Button */
.btn-secondary {
  background: var(--color-white);
  color: var(--color-black);
  border: 1px solid var(--color-gray-300);
}
.btn-secondary:hover {
  background: var(--color-gray-50);
}
```

#### Cards
```css
.card {
  background: var(--color-white);
  border: 1px solid var(--color-gray-200);
  border-radius: 8px;
  padding: 1.5rem;
}
```

#### Inputs
```css
.input {
  background: var(--color-white);
  border: 1px solid var(--color-gray-300);
  border-radius: 6px;
  padding: 0.5rem 0.75rem;
  transition: border 150ms;
}
.input:focus {
  outline: none;
  border-color: var(--color-black);
  box-shadow: 0 0 0 3px rgba(0, 0, 0, 0.05);
}
```

---

## Environment Variables

### Frontend (.env)
```bash
VITE_API_URL=http://localhost:7777
VITE_APP_NAME=TCS PacePort Scheduler
VITE_APP_URL=http://localhost:3000
```

### Backend (.env)
```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/tcs_scheduler

# Auth
SESSION_SECRET=your-super-secret-session-key-change-in-production

# Email (Resend)
RESEND_API_KEY=re_xxx
FROM_EMAIL=noreply@tcs.com
FROM_NAME=TCS PacePort

# App
NODE_ENV=development
PORT=7777
FRONTEND_URL=http://localhost:3000

# Invitation
INVITATION_EXPIRY_DAYS=7
```

---

## Development Commands & Workflow

### Initial Setup

```bash
# 1. Clone and setup backend
cd sched-be
bun install
cp .env.example .env
# Edit .env with your database credentials

# 2. Setup database
bunx prisma generate
bunx prisma db push
bun run seed  # Creates default admin user

# 3. Setup frontend
cd ../sched-fe
bun install
cp .env.example .env
# Edit .env if needed
```

### Running Development (Always use background mode)

```bash
# Backend (run in background)
cd sched-be
bun run dev  # Starts on port 7777

# Frontend (run in background)
cd sched-fe
bun run dev  # Starts on port 3000

# Monitor running processes
# Use /bashes command in Claude Code or BashOutput tool
```

### Standard Commands

**Backend (package.json):**
```json
{
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "build": "bun build src/index.ts --outdir ./dist --target bun",
    "start": "bun run dist/index.js",
    "db:generate": "bunx prisma generate",
    "db:push": "bunx prisma db push",
    "db:migrate": "bunx prisma migrate dev",
    "db:migrate:deploy": "bunx prisma migrate deploy",
    "db:seed": "bun run prisma/seed.ts",
    "db:studio": "bunx prisma studio",
    "test": "bun test"
  }
}
```

**Frontend (package.json):**
```json
{
  "scripts": {
    "dev": "rsbuild dev --port 3000",
    "build": "rsbuild build",
    "preview": "rsbuild preview",
    "type-check": "tsc --noEmit"
  }
}
```

### Database Seed Script

Create default admin user:

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client';
import { hash } from '@node-rs/argon2';

const prisma = new PrismaClient();

async function main() {
  // Create default admin
  const passwordHash = await hash('TCSPacePort2024!', {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  });

  const admin = await prisma.user.upsert({
    where: { email: 'admin@tcs.com' },
    update: {},
    create: {
      email: 'admin@tcs.com',
      passwordHash,
      name: 'TCS Admin',
      role: 'ADMIN',
    },
  });

  console.log('✅ Created admin user:', admin.email);
  console.log('🔑 Password: TCSPacePort2024!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

---

## CLAUDE.md Context File

**Create this file in the project root for Claude Code to reference:**

```markdown
# TCS PacePort Scheduler - Project Context

## Quick Reference

### Project Structure
- **Frontend**: `sched-fe/` - React + RSBuild + TailwindCSS (Port 3000)
- **Backend**: `sched-be/` - Bun + Hono + Prisma (Port 7777)
- **Database**: PostgreSQL

### Always Run in Background
```bash
# Backend
cd sched-be && bun run dev

# Frontend
cd sched-fe && bun run dev

# Use run_in_background: true parameter when calling Bash tool
```

### Key Technologies & Documentation
- **RSBuild**: https://rsbuild.dev - Check docs for build config, plugins, PWA setup
- **Hono**: https://hono.dev - Check docs for routing, middleware, validation
- **Prisma**: https://prisma.io/docs - Check docs for schema, queries, migrations
- **Lucia Auth**: https://lucia-auth.com - Check docs for session management
- **TanStack Query**: https://tanstack.com/query - Check docs for data fetching
- **Zod**: https://zod.dev - Used for all validation (frontend + backend)

### Pre-installed UI Components
All shadcn/ui components are in `sched-fe/src/components/ui/`:
- Forms: input, textarea, select, checkbox, radio-group, switch
- Feedback: alert, alert-dialog, dialog, sheet, drawer, toast (sonner)
- Data: table, card, calendar
- Navigation: tabs, sidebar, navigation-menu, breadcrumb
- Overlay: popover, dropdown-menu, context-menu, tooltip, hover-card
- Layout: separator, scroll-area, resizable, aspect-ratio
- Media: avatar, carousel
- Other: button, badge, spinner, skeleton, progress, slider, kbd

**Never create new UI components - use existing ones!**

### Default Credentials
```
Email: admin@tcs.com
Password: TCSPacePort2024!
```

### Common Commands

**Database:**
```bash
bunx prisma generate       # Generate Prisma client (run after schema changes)
bunx prisma db push        # Push schema to DB (development)
bunx prisma migrate dev    # Create migration (development)
bunx prisma migrate deploy # Deploy migration (production)
bunx prisma studio         # Open Prisma Studio GUI
bun run seed              # Seed database with admin user
```

**Development:**
```bash
bun run dev        # Start dev server (both FE/BE)
bun run build      # Build for production
bun run type-check # TypeScript check (frontend only)
bun test          # Run backend tests
```

### Project Rules

1. **Always run dev servers in background** using `run_in_background: true`
2. **Never create new UI components** - use pre-installed from `components/ui/`
3. **Always use Zod** for all validation (forms, API, etc.)
4. **Check docs first** - Use WebFetch tool to read official documentation before implementing
5. **PostgreSQL only** - no SQLite or other databases
6. **TCS black & white theme** - use only grayscale colors
7. **RSBuild specific** - Always check https://rsbuild.dev for build/config questions

### Validation Pattern

**Frontend (React Hook Form + Zod):**
```typescript
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { BookingCreateSchema } from '@/types';

const form = useForm({
  resolver: zodResolver(BookingCreateSchema),
  defaultValues: { ... }
});
```

**Backend (Hono + Zod):**
```typescript
import { zValidator } from '@hono/zod-validator';
import { BookingCreateSchema } from '../types';

app.post('/bookings', 
  zValidator('json', BookingCreateSchema), 
  async (c) => {
    const data = c.req.valid('json'); // Fully typed!
    // ...
  }
);
```

### API Base URLs
- Frontend: http://localhost:3000
- Backend: http://localhost:7777
- API: http://localhost:7777/api

### Booking Business Rules
- **3h slots**: 09:00-12:00 (morning) OR 14:00-17:00 (afternoon)
- **6h slots**: 09:00-17:00 (full day, blocks both 3h slots)
- **A day can have**: 
  - 2x 3h bookings (one morning + one afternoon)
  - 1x 6h booking (blocks entire day)
  - 1x 3h booking (leaves other slot available)

### User Roles & Permissions
- **ADMIN**: Full system access, manage users
- **MANAGER**: Create bookings, generate invitations
- **GUEST**: Book via invitation token only (no login)

### Color System (Tailwind)
```
Backgrounds: bg-white, bg-black, bg-gray-50 to bg-gray-900
Text: text-black, text-gray-600 (secondary), text-gray-400 (muted)
Borders: border-gray-200, border-gray-300
Hover: hover:bg-gray-50, hover:bg-gray-800
```

### Calendar States
- **Available**: White (bg-white)
- **Partially booked**: Light gray (bg-gray-100)
- **Fully booked**: Dark gray (bg-gray-800)
- **Past date**: Disabled (bg-gray-200)

### Error Handling Strategy
1. All API calls wrapped in try-catch
2. Use Zod for input validation (returns helpful errors)
3. Show user-friendly error messages via toast
4. Log detailed errors to console (development only)
5. Never expose sensitive error details to users

### Security Checklist
- ✅ CORS configured for localhost:3000
- ✅ Session-based auth (Lucia)
- ✅ Passwords hashed with Argon2
- ✅ Invitation tokens single-use, expire in 7 days
- ✅ All inputs validated with Zod
- ✅ Rate limiting on public endpoints
- ✅ SQL injection protection via Prisma

### File Naming Conventions
- React components: PascalCase.tsx
- Utilities/services: camelCase.ts
- Types: index.ts (centralized)
- Pages: page.tsx (Next.js App Router style)
- No default exports except for pages

### TypeScript Rules
- Strict mode enabled
- No `any` types allowed
- All Zod schemas must have inferred types
- Props interfaces for all components
- Return types for all functions

### Development Workflow
1. **Before implementing features**:
   - Use WebFetch to check official docs
   - Search codebase for similar patterns (Grep/Glob)
   - Check existing components/utilities
   
2. **When stuck**:
   - Read error messages carefully
   - Check relevant documentation
   - Use Task tool for complex searches
   - Validate against Zod schemas

3. **Git workflow**:
   - Never commit without user request
   - Review all changes before committing
   - Use conventional commit messages
   - Never commit .env files

### RSBuild Configuration Notes
- PWA setup via `@rsbuild/plugin-pwa`
- PostCSS for TailwindCSS processing
- React plugin pre-configured
- Check https://rsbuild.dev/config for all options
- Environment variables prefixed with `VITE_`

### Testing Notes
- Backend: Bun test framework
- Frontend: No tests initially (can add later)
- E2E: Consider Playwright for critical flows
- Focus on service/utility testing first

### Common Pitfalls to Avoid
❌ Creating new UI components instead of using existing
❌ Forgetting to validate with Zod on backend
❌ Not running services in background
❌ Using colors outside black/white palette
❌ Skipping documentation check before implementing
❌ Assuming library availability without checking package.json
❌ Committing without user request

### When Implementing New Features
1. ✅ Check if similar feature exists (search codebase)
2. ✅ Read official docs for libraries being used
3. ✅ Create Zod schemas for data validation
4. ✅ Use existing UI components
5. ✅ Follow TCS black/white design system
6. ✅ Add proper TypeScript types
7. ✅ Implement error handling
8. ✅ Test manually before marking complete
```

---

## PWA Configuration

### Manifest (public/manifest.json)
```json
{
  "name": "TCS PacePort Scheduler",
  "short_name": "TCS Scheduler",
  "description": "Schedule your visit to TCS PacePort São Paulo",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#000000",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

### RSBuild PWA Plugin Configuration
```typescript
// rsbuild.config.ts
import { defineConfig } from '@rsbuild/core';
import { pluginReact } from '@rsbuild/plugin-react';
import { pluginPWA } from '@rsbuild/plugin-pwa';

export default defineConfig({
  plugins: [
    pluginReact(),
    pluginPWA({
      manifest: {
        name: 'TCS PacePort Scheduler',
        short_name: 'TCS Scheduler',
        theme_color: '#000000',
      },
      workbox: {
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-cache',
              expiration: {
                maxEntries: 10,
                maxAgeSeconds: 60 * 60 * 24 * 365, // 1 year
              },
            },
          },
          {
            urlPattern: /\/api\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              networkTimeoutSeconds: 10,
            },
          },
        ],
      },
    }),
  ],
});
```

**Always check https://rsbuild.dev/plugins/list/plugin-pwa for latest PWA configuration options**

---

## Predefined Options (Constants)

```typescript
// src/lib/constants.ts

export const COMPANY_SECTORS = [
  'Technology',
  'Financial Services',
  'Healthcare',
  'Retail',
  'Manufacturing',
  'Energy',
  'Telecommunications',
  'Government',
  'Education',
  'Other',
] as const;

export const COMPANY_VERTICALS = [
  'Banking',
  'Insurance',
  'Capital Markets',
  'Healthcare Provider',
  'Life Sciences',
  'Retail',
  'Manufacturing',
  'Energy & Utilities',
  'Public Sector',
  'Horizontal (Cross-industry)',
] as const;

export const INTEREST_AREAS = [
  'Artificial Intelligence',
  'Cloud Migration',
  'Digital Transformation',
  'Data Analytics',
  'Cybersecurity',
  'DevOps',
  'IoT',
  'Blockchain',
  'Automation',
  'Legacy Modernization',
  'Other',
] as const;

export const COMPANY_SIZES = [
  'Small (1-50 employees)',
  'Medium (51-500 employees)',
  'Large (501-5000 employees)',
  'Enterprise (5000+ employees)',
] as const;

export const TIME_SLOTS = {
  MORNING: '09:00',
  AFTERNOON: '14:00',
} as const;

export const VISIT_DURATION_LABELS = {
  THREE_HOURS: '3 hours',
  SIX_HOURS: '6 hours (Full day)',
} as const;
```

---

## Backend Implementation Examples

### Hono App Setup (src/index.ts)
```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import authRoutes from './routes/auth';
import bookingRoutes from './routes/bookings';
import invitationRoutes from './routes/invitations';
import userRoutes from './routes/users';
import { errorHandler } from './middleware/errorHandler';

const app = new Hono();

// Middleware
app.use('*', logger());
app.use('*', cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true,
}));

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/bookings', bookingRoutes);
app.route('/api/invitations', invitationRoutes);
app.route('/api/users', userRoutes);

// Error handling
app.onError(errorHandler);

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

const port = process.env.PORT || 7777;
console.log(`🚀 Server running on http://localhost:${port}`);

export default {
  port,
  fetch: app.fetch,
};
```

### Zod Validation Middleware Example
```typescript
// routes/bookings.ts
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { BookingCreateSchema, BookingUpdateSchema } from '../types';
import { authMiddleware } from '../middleware/auth';
import * as bookingService from '../services/booking.service';

const app = new Hono();

app.post('/',
  authMiddleware,
  zValidator('json', BookingCreateSchema),
  async (c) => {
    const user = c.get('user');
    const data = c.req.valid('json');
    
    const booking = await bookingService.createBooking(data, user.id);
    return c.json(booking, 201);
  }
);

app.patch('/:id',
  authMiddleware,
  zValidator('json', BookingUpdateSchema),
  async (c) => {
    const id = c.req.param('id');
    const data = c.req.valid('json');
    
    const booking = await bookingService.updateBooking(id, data);
    return c.json(booking);
  }
);

export default app;
```

---

## Deployment Checklist

### Pre-deployment
- [ ] Run type checks: `bun run type-check`
- [ ] Build frontend: `cd sched-fe && bun run build`
- [ ] Build backend: `cd sched-be && bun run build`
- [ ] Run database migrations: `bunx prisma migrate deploy`
- [ ] Set production environment variables
- [ ] Test email sending (Resend)
- [ ] Verify CORS settings
- [ ] Test authentication flow
- [ ] Verify booking availability logic
- [ ] Test invitation token flow

### Environment Variables (Production)
```bash
# Backend
DATABASE_URL=postgresql://prod-user:prod-pass@db-host:5432/tcs_scheduler
SESSION_SECRET=use-strong-random-secret-min-32-chars
RESEND_API_KEY=re_production_key
FRONTEND_URL=https://scheduler.tcs.com
NODE_ENV=production
PORT=7777
INVITATION_EXPIRY_DAYS=7

# Frontend
VITE_API_URL=https://api.scheduler.tcs.com
VITE_APP_NAME=TCS PacePort Scheduler
VITE_APP_URL=https://scheduler.tcs.com
```

### Performance Optimizations
- Enable Prisma connection pooling
- Configure CDN for static assets (RSBuild output)
- Enable Brotli/gzip compression
- Implement Redis for session storage (optional upgrade)
- Add database indexes (already in schema)
- Enable RSBuild production optimizations
- Use Lighthouse to audit PWA score

---

## Critical Implementation Guidelines

### 1. Documentation-First Approach
**Before implementing any feature, always check official documentation:**

```typescript
// Example: Before implementing RSBuild plugin
// Use WebFetch tool:
WebFetch('https://rsbuild.dev/plugins/list/plugin-pwa', 
  'How to configure PWA plugin with workbox?'
)

// Example: Before implementing Lucia auth
WebFetch('https://lucia-auth.com/guides/getting-started/hono',
  'How to setup Lucia with Hono and Prisma?'
)

// Example: Before creating Prisma query
WebFetch('https://prisma.io/docs/concepts/components/prisma-client/crud',
  'How to query with date range filters?'
)
```

### 2. Zod Validation Pattern
**All data must be validated with Zod on both frontend and backend:**

```typescript
// 1. Define schema in types/index.ts
export const BookingCreateSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  // ... rest of schema
});

// 2. Frontend validation (React Hook Form)
const form = useForm({
  resolver: zodResolver(BookingCreateSchema),
});

// 3. Backend validation (Hono)
app.post('/bookings', 
  zValidator('json', BookingCreateSchema),
  async (c) => {
    const data = c.req.valid('json'); // Type-safe!
  }
);
```

### 3. Background Process Management
**Always run development servers in background:**

```typescript
// When calling Bash tool:
{
  command: 'cd sched-be && bun run dev',
  description: 'Start backend server',
  run_in_background: true  // ALWAYS TRUE for dev servers
}

// Monitor output:
BashOutput({ bash_id: 'xxx' })

// Kill if needed:
KillBash({ shell_id: 'xxx' })
```

### 4. Error Handling Pattern
```typescript
// Frontend
try {
  const response = await api.post('/bookings', data);
  toast.success('Booking created successfully');
} catch (error) {
  if (error.response?.data?.message) {
    toast.error(error.response.data.message);
  } else {
    toast.error('An error occurred. Please try again.');
  }
  console.error('Booking error:', error);
}

// Backend
app.onError((err, c) => {
  console.error('Error:', err);
  
  if (err instanceof ZodError) {
    return c.json({ 
      message: 'Validation error', 
      errors: err.errors 
    }, 400);
  }
  
  return c.json({ 
    message: 'Internal server error' 
  }, 500);
});
```

### 5. Code Quality Standards
- ✅ No `any` types in TypeScript
- ✅ All API responses properly typed
- ✅ Extract repeated logic to utilities
- ✅ Components under 200 lines
- ✅ Meaningful variable names
- ✅ Handle loading/error states
- ✅ Use existing UI components
- ✅ Follow TCS black/white theme
- ✅ No commented-out code in commits

### 6. Git Workflow
- ⚠️ **NEVER commit without explicit user request**
- ✅ Always review changes before committing
- ✅ Use conventional commit format
- ✅ Never commit `.env` or `.env.local`
- ✅ Always include `.gitignore`

---

## Troubleshooting Guide

### Common Issues & Solutions

#### 1. Database Connection Fails
```bash
# Check PostgreSQL is running
pg_isready

# Verify DATABASE_URL format
postgresql://user:password@localhost:5432/database

# Test connection
bunx prisma db push

# Reset if needed
bunx prisma migrate reset
```

#### 2. Frontend Can't Reach Backend
```bash
# Check CORS settings in backend (should allow localhost:3000)
# Verify VITE_API_URL in frontend .env
# Ensure backend is running on correct port
curl http://localhost:7777/health
```

#### 3. Prisma Client Out of Sync
```bash
# After schema changes, always run:
bunx prisma generate

# Then restart dev servers
```

#### 4. Zod Validation Errors
```typescript
// Check schema matches form data structure
// Use .safeParse() for debugging:
const result = BookingCreateSchema.safeParse(data);
if (!result.success) {
  console.log('Validation errors:', result.error.errors);
}
```

#### 5. Session Not Persisting
```bash
# Verify SESSION_SECRET is set in .env
# Check Lucia configuration includes credentials: true
# Ensure frontend axios includes withCredentials: true
```

#### 6. RSBuild Build Errors
```bash
# Check https://rsbuild.dev for config issues
# Clear cache and rebuild:
rm -rf dist node_modules/.cache
bun run build
```

---

## Final Reminders

### Before Starting Development:
1. ✅ Read this entire document
2. ✅ Setup CLAUDE.md in project root
3. ✅ Install PostgreSQL
4. ✅ Configure .env files
5. ✅ Run database migrations
6. ✅ Seed admin user
7. ✅ Test both servers start in background

### During Development:
1. 🔍 **Always check docs first** (RSBuild, Hono, Prisma, Lucia)
2. ✅ **Use Zod** for all validation
3. ✅ **Use existing UI components** from `components/ui/`
4. ✅ **Run servers in background** mode
5. ✅ **Follow TCS black/white theme**
6. ✅ **No commits** without user request
7. ✅ **Type everything** with TypeScript
8. ✅ **Test manually** before marking complete

### Key Success Factors:
- 📚 Documentation-first approach
- 🎯 Use Zod for type-safe validation
- 🎨 Strict adherence to black/white design
- 🔒 Security best practices (Lucia, Zod, Prisma)
- ⚡ Background process management
- 🧩 Reuse existing components
- 🐛 Proper error handling everywhere

---

**This document is the single source of truth for the TCS PacePort Scheduler project. Follow it sequentially, validate against official documentation using WebFetch tool, and maintain high code quality throughout development.**     