# Overseer

A native Tern Projects navigator backed by Worktrunk. Projects point at local Git repositories; each worktree opens a dedicated Tern session with its own tabs.

## Install

Requires desktop Tern with the sessions/canvas APIs (verified with 0.4.5), Git, Bash, and Worktrunk (`wt`, verified with 0.40.0). Pull request badges also need the [GitHub CLI](https://cli.github.com) (`gh`), signed in with `gh auth login`; without it the panel works and simply shows no badges.

From this directory:

```sh
/Applications/Tern.app/Contents/MacOS/tern plugin link "$PWD"
```

If `tern` is on your PATH, `tern plugin link "$PWD"` is equivalent. Linking reloads the plugin when its source changes. Keep this directory in place. Use `tern plugin install "$PWD"` instead to install a separate copy.

## Use

1. Press **Cmd+Option+Shift+P**, or run **Open Projects** from Tern's command palette.
2. Click **+** in the Projects header. Enter a checkout directory, optionally a display name and a local base branch. `~/` paths and linked checkouts work; duplicate repositories are detected by their canonical shared Git directory.
3. Click a worktree to open its session. Each worktree is shown as a group: its name, a subtitle (the branch when renamed, otherwise the directory), and its open tabs beneath. The active session's whole group is highlighted. A filled green dot means a session is open, a **pulsing** green dot means an agent is working in it, a hollow dot means none, and amber marks running tabs or a deletion in progress. Click an indented tab to focus it. New tabs in a managed session start at its worktree root.
4. Click **New Worktree** beside a project. Enter a new branch name and, optionally, a **Display name** (Tab moves to it). A separate **Create: …** terminal shows Worktrunk's approval prompt and setup output.
5. After creation, return to Projects and select the new worktree. Review the setup terminal's output before closing it; Enter ends the helper after review.
6. Right-click a worktree for **Rename**, **Add to Ice Box**, **Close session**, or **Delete worktree**. Rename sets a friendly Projects label; close and delete ask for confirmation. Close keeps the files; delete removes the directory but keeps the Git branch.

Click the info icon immediately after the **Projects** heading to open this guide in a rendered Markdown tab. Its tooltip is **How Projects works**. The button reads the README bundled with the installed plugin, so it works offline and when you share or copy the plugin to another machine.

Add project, New worktree, and Rename open **in place of the Projects panel**, like a page within it: same position, same width, so the rest of your layout never shifts. Click **← Projects** or press Esc to go back without changes; submitting returns to Projects too. While a form is showing, the Projects shortcut focuses it rather than opening a second panel. Forms support Tab/Shift+Tab, Enter, Escape, arrows, selection, Cmd+A/C, and Unicode text. Validation failures leave the form editable. **Refresh** discovers externally created/removed worktrees; an open navigator also refreshes every 15 seconds.

The navigator is a native pane, not an application-wide sidebar. It opens to the left of the first terminal of a new worktree session, using approximately one-third of the width (rounded to Tern's resize increment). It is not duplicated into every tab. The shortcut returns to that session's existing navigator, even from another tab. Resize its divider using Tern's normal controls; reopening Projects or switching worktrees preserves that session's adjusted width.

**Display names** change only the Projects row, not the Git branch, worktree directory, or Tern session name. For example, keep branch `ALL-2456` and label its row `Fix onboarding`. Set one when creating the worktree, or later with **Rename**. A name given at creation is applied once Worktrunk has created the worktree, even if setup hooks later fail; a rename made while setup is still running takes precedence. Hover the row to see its branch and full path. Names are saved per project/worktree and survive refreshes, session closure, and restarts. Clear the display-name field and save to restore the branch label. Successful deletion through Overseer removes the saved name too.

**Ice Box** parks worktrees you aren't working on. Right-click a worktree and choose **Add to Ice Box**: it moves to the bottom of its project with 🧊 in place of its dot, and nothing else changes (its files, branch, and session stay as they are). The **🧊** button beside **↻** hides or shows ice-boxed worktrees; while hidden, each project shows a "🧊 N in the Ice Box" link that shows them again. The worktree you're currently in stays visible even when the Ice Box is hidden. **Remove from Ice Box** puts it back in its usual place. The primary checkout can't be iced. The Ice Box and the show/hide choice survive restarts; deleting a worktree through Overseer also removes it from the Ice Box.

**Agent activity:** the dot pulses while an agent is working in that worktree's session. That covers agent CLIs run in a terminal (`omp`, `pi`, `claude`, `codex`, `opencode`, `gemini`, `aider`, `amp`, `cursor-agent`, `crush`, `goose`) and Tern's own agent blocks. A terminal agent counts as working while it reports progress to the terminal; omp does this during each turn, so between turns its dot is steady green. A CLI that doesn't report progress (or hasn't yet, like Claude right after launch) counts as working for as long as it runs. With the system's reduce-motion setting on, a static ring replaces the pulse.

**Pull request badges** appear at the right end of a worktree's row when its branch has a GitHub pull request. They use GitHub's own Octicons and colours: grey draft, green open, purple merged, red closed. Hover for the number and state ("#2435 · Merged"); click to open the PR, following Tern's link setting. If a branch has several PRs, the open one wins, otherwise the most recently updated. PRs are matched by branch name, so merged PRs still show after GitHub deletes their branch. The primary checkout and branches without a PR show no badge.

Each project makes one request through your signed-in `gh`, in the background, at most every 2 minutes, and right away when worktrees are added or removed or you click **↻**. Only projects whose `origin` is on github.com are checked. If a lookup fails (offline, signed out), the last known badges stay; the error is written to Tern's log.

The pull request and info icons are [Primer Octicons](https://primer.style/octicons/) (MIT, `icons/LICENSE`). Tern plugin stylesheets can't load image files, so `icons/generate-css.py` embeds them in `icons.css`; rerun it after replacing an SVG.

## Creation and trust

Overseer runs the equivalent of:

```sh
wt -C /path/to/project switch --create --base master --no-cd new-branch
```

The project's selected base replaces `master`. With no explicit base, registration prefers local `master`, then the local branch named by `origin/HEAD`, then local `main`. If none exists, enter a local branch in the form. No fetch, pull, checkout of the primary directory, or forced overwrite occurs.

Creation preserves the terminal's stdin/stdout/stderr. Overseer never supplies `--yes` or `--no-hooks`. Worktrunk handles approvals, blocking `pre-start` hooks, and background hooks normally. Declining approval may still create a worktree **without running project hooks**, as Worktrunk documents.

“Worktree created” means the Worktrunk command returned zero, **not** that every setup task succeeded. Hooks can warn and exit zero, and background hooks can still be running. Some project setup scripts deliberately return zero on partial failures; review their warnings. A nonzero command status is surfaced in Projects, and partially created worktrees remain discoverable.

The outcome comes from a receipt the helper writes when it finishes, not from the terminal's state. If Tern stops reporting the setup terminal while the helper is still running (for example, after a window restart), Overseer checks the helper's process and keeps waiting. It reports a failure only when that process is gone without having written a receipt.

Arguments are encoded before entering the login shell and decoded only inside Bash, then passed as quoted arguments. Unicode, spaces in paths, quotes, dollar signs, and semicolons are not evaluated as shell code. Creation was exercised through both zsh and Nushell.

## Close and delete

**Close session** stops its running programs and closes its tabs. The worktree stays listed and can be reopened. Locked sessions must be unlocked first. A session with a pending Worktrunk operation cannot be closed through this menu until that operation finishes or is cancelled in its terminal.

**Delete worktree** runs:

```sh
wt -C /path/to/project remove --foreground --no-delete-branch -- /path/to/worktree
```

The **Delete: …** terminal opens in the primary checkout's session, not the session being deleted, so its output remains available afterward. Worktrunk keeps its normal hook approval prompts and removal hooks; Overseer never adds `--yes`, `--no-hooks`, or force flags.

The primary checkout cannot be deleted. Uncommitted changes and untracked files block removal. The target's repository identity, branch, and cleanliness are rechecked before invoking Worktrunk. **Ignored files are removed with the directory**; copy anything needed first, and stop programs that are writing into it.

Only a zero exit status with the directory gone triggers closing its managed session. Failures leave the session open and retain the removal terminal for diagnosis. If the session becomes locked during removal, it is left open with an explicit warning. Cancelling the confirmation, or reloading the plugin before the command starts, does not delete anything.

## State and scope

Project records, worktree display names, and worktree/session associations live in Tern's `plugin-data/overseer/kv.json`. Tern owns the actual sessions, tabs, shells, and persisted canvas contents. Reloading the plugin restores form drafts, names, and session associations without recreating worktrees. Closing a form's pane during validation cancels its pending operation.

This plugin manages **local repositories**. It does not clone repositories, delete Git branches, move existing unrelated tabs, or replace Tern's global navigation. Existing worktrees are listed even if they have no Tern session yet. Unlinking the plugin does not remove worktrees or stop existing terminal sessions:

```sh
/Applications/Tern.app/Contents/MacOS/tern plugin unlink overseer
```

## Implementation

- `window.luau`: project registry, async discovery, session ownership, confirmation actions, swapping forms into the Projects panel's place, and lifecycle jobs.
- `worktrunk.luau`: Git/Worktrunk discovery, validation, shell-safe operation commands, and the GitHub pull request lookup.
- `worktree-operation.sh`: interactive creation/removal and atomic completion receipts.
- `view.luau`, `styles.css`, `icons.css` (generated): native project/worktree/tab hierarchy, PR badges, and the info icon.
- `icons/`: Primer Octicons, their license, and `generate-css.py`.
- `host.luau`, `input.luau`: native forms and Unicode-aware text editing.

## Verification

Exercised in a **real Tern desktop window**, with a separate Tern configuration and a disposable repository. Temporary hook approvals were removed afterward.

- Registration of a path containing spaces, an apostrophe, and Unicode; discovery of a Git-created linked worktree.
- Separate worktree sessions, root-directory new tabs, and reuse of sessions after plugin reload.
- Editable invalid-path and invalid-branch errors; form draft restoration and cancellation after reload.
- Interactive hook approval; a setup hook creating a marker in the new worktree.
- Creation from `master` while the active worktree's branch had diverged.
- Literal Unicode/shell-metacharacter branch names; zsh and Nushell launch paths.
- Hook exit status 23 retained in the output and surfaced as a creation failure, with the partial worktree listed.
- A real repository with eight existing worktrees displayed in the navigator, without creating or deleting any of its worktrees or running its hooks.
- Native right-click menus, close/cancel confirmations, and active-session closure without deleting its worktree.
- Interactive removal approval, a real `pre-remove` hook, branch retention, and closure of the deleted worktree's session and running shell while preserving the output tab.
- Dirty-worktree rejection with its files and session retained.
- Primary-checkout menus without deletion, locked-session refusal, detached worktree removal, cancellation, and closing the last managed session while retaining a usable Projects session.
- A failing `pre-remove` hook preserved the worktree and session and surfaced the failure, including a cold primary-session launch in Tern's daemonless mode.
- Creation still worked through the renamed helper with a literal Unicode/shell-metacharacter branch. Detached deletion exercised empty-argument encoding under macOS Bash 3.2.

The helper also passes `bash -n`. Run the nine real Git/Worktrunk regression tests with Python 3:

```sh
python3 -B tests/test_worktree_operation.py -v
```

Tests use temporary repositories, configuration, and approvals. They cover staged/untracked-file protection, primary and foreign-repository rejection, branch changes after confirmation, failing removal hooks, retention of unmerged branches, removal of ignored files, detached worktree removal, and creation from the selected base with literal shell metacharacters.

These checks are not a claim of exhaustive compatibility across Tern versions or multiple-window concurrency.
