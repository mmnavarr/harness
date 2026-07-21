---
name: skeleton
description: Use when the user has a plan or feature outline and wants boilerplate/stub code that derisks implementation before the real logic is written. Triggers on requests to create a code skeleton, scaffold stubs from a plan, outline broad implementation strokes in code, or show file/function/dependency layout without filling in the meat.
tags: [engineering, scaffolding, planning, first-draft]
---

# Skeleton

Create a reviewable implementation skeleton from a plan: real files, real names, real module boundaries, real call flow, and intentionally empty implementation bodies. The goal is to derisk shape before substance so reviewers can inspect where code will live, how dependencies connect, which methods exist, and how the workflow is composed.

This skill is only for explicit skeleton/scaffold/stub requests. Do not use it for normal implementation work, and do not present skeleton code as a finished feature.

## Output contract

A good skeleton answers these questions in code:

- Which files are created or modified?
- Which public types, functions, methods, routes, jobs, commands, or components exist?
- How does control flow move through them?
- Which dependencies are accepted, imported, injected, or constructed?
- Where will validation, persistence, external calls, rendering, and error handling eventually live?
- What names will future implementers and reviewers discuss?

A skeleton must not answer business-logic questions yet:

- No real algorithms.
- No real persistence logic.
- No real network/API behavior beyond existing framework registration.
- No fake fallbacks, mock data, or silent placeholder success.
- No tests that assert stubbed behavior as if it were complete.

## Procedure

1. **Read the plan first.** Extract the concrete workflow, inputs, outputs, actors, external dependencies, and acceptance criteria. If the plan is missing a critical boundary, infer from existing repo conventions before asking.
2. **Map the target code shape.** Use `find`, `search`, `read`, `lsp`, and existing patterns to identify where analogous files live, how names are formed, and how dependencies are wired. Do not invent a second architecture beside an existing one.
3. **Create the smallest coherent file set.** Prefer modifying existing extension points over creating new top-level structures. Add files only when the planned feature needs a distinct module, route, service, component, command, or test seam.
4. **Write real signatures and types.** Include parameters, return types, data structures, interface/protocol methods, constructor dependencies, exports, and imports. Make names boring and specific.
5. **String the workflow together.** Entry points should call the next planned layer so reviewers can follow the path end-to-end. Wire dependency injection, registration, routing, exports, and composition exactly as the final implementation is expected to use them.
6. **Stub bodies loudly.** Bodies should fail fast with an intentional not-implemented signal (`throw new Error("Not implemented: ...")`, `raise NotImplementedError`, `todo!()`, `panic!("not implemented: ...")`, etc.) or return a language/framework-required placeholder only when failing is impossible. Never silently return plausible fake data.
7. **Mark intent locally.** Use short comments only where a stub boundary would otherwise be ambiguous: `// Skeleton: validation lives here.` Avoid long explanatory prose in code.
8. **Add compile-only safety when useful.** It is acceptable to add type-only tests, fixtureless compile checks, or route/module registration checks if they prove the skeleton is wired. Do not add behavior tests for unimplemented logic.
9. **Verify the skeleton, not the feature.** Run the narrowest formatter/typecheck/build/import check that proves files parse and dependencies resolve. If intentional stubs make runtime execution fail, stop at the first expected not-implemented boundary and report that boundary as evidence.

## Stub design rules

- Stubs are deliberate failure points, not fake implementations.
- Prefer dependency injection over constructing clients deep inside stubs; reviewers should see what the real implementation will need.
- Preserve production signatures even when bodies are empty.
- Keep call chains shallow enough to read, but complete enough to show the workflow.
- Avoid speculative abstractions. If the plan names one provider, write one provider seam; do not build a plugin system.
- Delete obsolete placeholders or competing names introduced during skeletoning before yielding.
- If an existing public symbol must change, use `lsp references` and migrate every callsite affected by the shape change.

## What to include

Include only artifacts that reveal implementation shape:

- module/class/function definitions
- public interfaces/types/schemas
- route/controller/handler registration
- dependency injection wiring
- command/job/component entry points
- exports/index wiring
- migration or config filenames when the plan requires them, with empty/reversible bodies where supported
- compile/type-only tests if the repo convention already has a place for them

## What to avoid

- Real business logic hidden behind "just enough" placeholders.
- Mock servers, fake repositories, canned data, or green-path lies.
- New frameworks, registries, or abstractions not demanded by the plan.
- Broad formatting or cleanup unrelated to the skeleton.
- Documentation files unless the user explicitly asks for them.
- Claiming acceptance criteria are satisfied; skeletons only satisfy shape review.

## Review handoff

When done, summarize tersely:

- files added/modified
- entry point and call chain
- dependency seams created
- intentional not-implemented boundaries
- verification command run and observed result
- risks or plan ambiguities still visible in the skeleton

Use phrasing like: "Skeleton ready for shape review," not "feature complete."
