# product-map — maintenance notes

A progressive-disclosure catalog of products in the Alliance Network monorepo. See `SKILL.md` for the agent-facing contract.

## Layout

- `SKILL.md` — always-loaded entrypoint. Explains what a product is, the 5 pillars, and indexes every product.
- `products/<id>.md` — one page per product. Opened on demand.
- `scripts/stamp-commit.sh` — prints a `lastCheckedCommit` + `lastCheckedDate` block for frontmatter.

## Adding a new product

1. Pick a kebab-case `id` (e.g. `deal-memos`).
2. Copy the template from the bottom of `SKILL.md` into `products/<id>.md`.
3. Stamp the frontmatter with `bash scripts/stamp-commit.sh` (from inside the repo).
4. Add a row under the correct pillar in `SKILL.md`'s Product Index.

## Keeping pages fresh

Agents are instructed to verify `lastCheckedCommit` vs `origin/master` before relying on a page and to self-heal drift in the same turn. When you manually refresh a page:

```bash
cd /path/to/alliance-network
bash .agents/skills/product-map/scripts/stamp-commit.sh
```

Paste the two-line output into the page's frontmatter.

## Conventions

- Prefer linking to repo files over paraphrasing code.
- Keep product pages short (~100–200 lines). If a page grows too large, the product is probably two products.
- Mark broken references `⚠️ stale` instead of deleting — the next agent can fix them.
