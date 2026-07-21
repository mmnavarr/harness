# Applying Boolean Flags in Code

How to gate code behind a boolean PostHog flag. Documented for the **website**
(`apps/website`); other apps are not yet covered.

## Website (Next.js App Router) — server-side gate

### Reading flag values

Flag values come from `getBootstrapData()` in `apps/website/lib/posthog.ts`:

```ts
const { distinctID, featureFlags } = await getBootstrapData()
// featureFlags: Record<string, string | boolean>, cached per request
```

For a boolean flag the value is `true` / `false` / `undefined`.

### The boolean-vs-variant gotcha

Do **not** reuse `shouldShowForExperiment()` for a boolean flag. That helper maps any
value not in its variant table (`control`/`test`/...) back to "control", so a boolean
`true` is misread and the feature stays hidden. Use the dedicated helper in
`apps/website/lib/experiments/server.ts`:

```ts
// Accepts the string 'true' so local USE_MOCKING (EXPERIMENT_* env) overrides work.
export function isBooleanFlagEnabled(
  featureFlags: Record<string, unknown>,
  flagKey: string,
): boolean {
  const value = featureFlags?.[flagKey]
  return value === true || value === 'true'
}
```

### Gating a whole route segment (page + subpages)

Add a `layout.tsx` at the route segment — one file gates the page and all nested routes.
Example gating `/launches` and `/launches/[slug]`:

```tsx
// apps/website/app/launches/layout.tsx
import { isBooleanFlagEnabled } from 'lib/experiments/server'
import { getBootstrapData } from 'lib/posthog'
import { notFound } from 'next/navigation'
import type { ReactNode } from 'react'

export default async function LaunchesLayout({ children }: { children: ReactNode }) {
  const { featureFlags } = await getBootstrapData()

  if (!isBooleanFlagEnabled(featureFlags, 'launches')) {
    notFound()
  }

  return children
}
```

- Use `notFound()` to hide an unreleased feature (behaves as 404). Use `redirect('/')`
  if you'd rather send visitors somewhere.
- Gating in a `layout.tsx` covers every nested page in one place. Gate inside individual
  `page.tsx` files only when segments need independent flags.

### Side effect: dynamic rendering

`getBootstrapData()` reads the PostHog distinct id from cookies (`cookies()`), which makes
the gated routes **dynamically rendered**. Any `generateStaticParams()` static pre-render
in that segment no longer applies. This is expected and fine for a flag-gated feature.

## Local development

`USE_MOCKING` defaults to `true` in every non-production env
(`packages/env/src/index.ts`, `createUseMockingClientEnv`). In that mode
`getBootstrapData()` applies `EXPERIMENT_*` env overrides, so to see a flag locally set:

```bash
EXPERIMENT_<flag_key>=true bun run dev up website
# e.g. EXPERIMENT_launches=true bun run dev up website
```

The override arrives as the **string** `'true'`, which is why `isBooleanFlagEnabled`
accepts both `true` and `'true'`. In production (`USE_MOCKING=false`) `EXPERIMENT_*` is
ignored and the real PostHog flag value is used.

## Testing

`apps/website/lib/experiments/server.ts` imports `'server-only'`, so test it with a
dynamic import after mocking that module (mirrors `apps/website/lib/posthog.test.ts`):

```ts
mock.module('server-only', () => ({}))
mock.module('lib/logger', () => ({ logger: { warn: () => {}, error: () => {} } }))
const { isBooleanFlagEnabled } = await import('./server')
```

Cover: `true`, `false`, `'true'`, `'false'`, missing key, and a variant string (should be
false).

## Not yet covered

- webapp / admin gating patterns (these use the tRPC/session stack, not website's
  `getBootstrapData`).
- Client-side gating (`usePostHog().getFeatureFlag(...)`) for components that need the
  flag after hydration.
