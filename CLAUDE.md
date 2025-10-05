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

Always use bun.