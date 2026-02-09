# Frontend Agent Instructions

## Stack

- React 19 + Next.js 15 with App Router
- TypeScript strict mode
- Tailwind CSS v4 for styling
- Static export only (`output: 'export'` in next.config)
- Communicates with plumber2 API via fetch
- `API_BASE_URL` configured via environment variable (`NEXT_PUBLIC_API_BASE_URL`)
- No server-side features (no API routes, no SSR, no server components that fetch)
- shadcn/ui component library conventions
- File naming: kebab-case for files, PascalCase for components

## Architecture

This frontend is designed for **static export** and deployment to Posit Connect,
which has no Node.js runtime. All data fetching happens client-side via `fetch`
calls to a plumber2 (R) API backend.

## Key Constraints

- Every page/component that uses hooks or browser APIs must be marked `"use client"`
- No `getServerSideProps`, `getStaticProps`, or server actions
- No Next.js API routes (`app/api/`)
- Images must use `unoptimized: true` since there is no image optimization server
- All API communication goes through `src/lib/api.ts`
- Environment variable for API URL: `NEXT_PUBLIC_API_BASE_URL`

## Directory Structure

```
src/
  app/           # Next.js App Router pages and layouts
  components/    # Reusable UI components
  hooks/         # Custom React hooks
  lib/           # Utilities, API client
  types/         # TypeScript type definitions
```

## Commands

- `npm run dev` - Start development server on port 3000
- `npm run build` - Build static export (output to `out/`)
- `npm run lint` - Run ESLint

## Conventions

- Use `"use client"` directive for all interactive components
- Prefer named exports for components
- Use TypeScript strict mode - no `any` types without justification
- Keep API types in `src/types/index.ts`
- All colors/theming via CSS custom properties in `globals.css`
