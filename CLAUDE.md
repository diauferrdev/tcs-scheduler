# TCS PacePort Scheduler — Project Guide (CLAUDE.md)

Enterprise scheduling system for TCS PacePort São Paulo office visits: role-based
access, automated invitations, booking management with conflict/availability rules,
real-time updates and multi-platform clients.

> ⚠️ This project is **Flutter (frontend) + Bun/Hono (backend)**. It is NOT
> React/RSBuild — ignore any older docs that say otherwise.

---

## Monorepo layout

```
scheduler/
├── sched-be/   # Backend — Bun + Hono + Prisma + PostgreSQL (port 7777)
├── sched-fe/   # Frontend — Flutter (Web, Android, Windows, macOS, Linux, iOS)
├── CLAUDE.md
├── DEPLOY.md                 # build & deploy guide (READ before deploying)
└── PRODUCTION_CHECKLIST.md
```

- Repo: `github.com/diauferrdev/tcs-scheduler`, branch `main`.
- Local canonical checkout: `C:\tcs\scheduler`.

---

## Frontend — `sched-fe` (Flutter)

- **SDK**: Dart `^3.9.2` / Flutter. **Version source of truth**: `pubspec.yaml`
  → `version: <semver>+<build>` (e.g. `1.2.14+120`). The backend reads this file.
- **State**: `provider`. **Routing**: `go_router`.
- **Networking**: `http` + `web_socket_channel` (real-time) + `universal_html`.
- **Storage**: `shared_preferences`, `flutter_secure_storage`.
- **Forms/validation**: `flutter_form_builder`, `form_builder_validators`.
- **Dates/calendar**: `intl`, `table_calendar`.
- **Charts/PDF**: `fl_chart`, `syncfusion_flutter_charts/gauges/pdfviewer`, `pdf`, `printing`.
- **Notifications**: `firebase_messaging` (FCM), `firebase_core`, `flutter_local_notifications`, `local_notifier`.
- **Media**: `image_picker`, `file_picker`, `video_player`, `chewie`, `audioplayers`, `record`, `photo_view`.
- **Desktop**: `window_manager`, `msix` (Windows Store packaging).
- **Design**: TCS black/white theme. Brand fonts: `HouschkaRoundedAlt`, `BasisGrotesquePro`.
- **Lint**: `flutter analyze` (rules in `analysis_options.yaml`, `flutter_lints`).
- **Tests**: `flutter test`.

Run: `cd sched-fe && flutter pub get && flutter run -d chrome` (web).

---

## Backend — `sched-be` (Bun + Hono, port 7777)

- **Runtime/PM**: Bun (always `bun` / `bunx`, never npm/yarn). PM2 process `tcs-backend` (`ecosystem.config.cjs`).
- **Framework**: Hono `^4.8` + `@hono/zod-validator`. Check https://hono.dev for routes/middleware.
- **ORM**: Prisma `^6.2` + PostgreSQL 15+ (`src/lib/prisma.ts`, schema in `prisma/`). Check https://prisma.io/docs.
- **Auth**: Lucia `^3.2` + `@lucia-auth/adapter-prisma` + `@node-rs/argon2` (`src/lib/lucia.ts`). Check https://lucia-auth.com.
- **Validation**: Zod everywhere.
- **Real-time**: native WebSocket via `src/services/websocket.service.ts`.
- **Push**: `web-push` (web) + FCM (`src/routes/fcm.ts`, `push.ts`).
- **Misc**: `date-fns`, `music-metadata` (audio duration extraction).

### Structure
```
sched-be/src/
├── index.ts                 # app entry, mounts routes + WS
├── routes/                  # auth, bookings, invitations, rooms, tickets,
│                            # notifications, push, fcm, analytics, dashboard,
│                            # activity-logs, bugReports, upload, version, og
├── services/                # business logic (booking.service.ts is the core)
├── middleware/              # auth, errorHandler
├── lib/                     # prisma, lucia, context
├── utils/                   # token, time-overlap (pure, unit-tested)
├── types/
└── constants/
sched-be/scripts/            # DB/maintenance/debug scripts (NOT app code)
sched-be/prisma/             # schema + seed
sched-be/uploads/            # runtime uploads & built artifacts (gitignored)
```

### Commands
```bash
cd sched-be
bun run dev            # watch mode
bun test               # unit tests (src/**/*.test.ts)
bun run db:push        # apply schema (dev)
bun run db:migrate:deploy   # apply migrations (prod)
bun run db:seed
bun run db:studio
```

---

## Infrastructure (see DEPLOY.md for full guide)

| Service | URL | Process |
|---------|-----|---------|
| Frontend | https://pacesched.com | Caddy static (`sched-fe/build/web`) |
| Backend/WS | https://api.pacesched.com (`/ws`) | PM2 `tcs-backend`, localhost:7777 |
| Database | localhost:5432 | PostgreSQL 15+ |

- **VPS**: SSH alias `vps` → `root@aimaturity.lat`. Project at `/root/tcs/tcs-sched`.
- **Deploy**: `git pull origin main` on the VPS, then rebuild (see DEPLOY.md).
- Do NOT confuse with `ppspsched.lat` on the same VPS — that's a different project.

---

## Code quality standards

- TypeScript: no `any` (use `unknown`); type all API responses; Zod for all input.
- Components/services small and focused; extract repeated logic to `utils/`.
- Follow TCS black/white theme; reuse existing widgets/components.
- No commented-out / dead code in commits. No `console.log` left in final code.
- Pure logic (e.g. time/availability math) goes in `utils/` with a `*.test.ts`.

## Git workflow

- ⚠️ **NEVER commit or push without an explicit user request.**
- Conventional commit format. Never commit `.env`, keystores, certificates, or `uploads/`.
- GitHub `origin/main` is the source of truth; the VPS tracks it. Keep local in sync.

## Definition of done

- Backend: `bun test` passes; routes typed; no `any`; manual sanity check.
- Frontend: `flutter analyze` clean; verified visually.
- Version bumped in **`sched-fe/pubspec.yaml`** only (backend derives it).
