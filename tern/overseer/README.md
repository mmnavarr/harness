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
2. Click **+** in the Projects header (or run **Add project** from the command palette). The macOS folder picker opens, starting beside the last project you added (or in `~/code`). Choose a repository's folder and it's added right away, named after the folder. Choosing a folder that isn't a Git repository reopens the picker there; cancelling does nothing. Linked checkouts work, and duplicates are detected by the repository's shared Git directory. Hover a project's name to see its path.
3. Click a worktree to open its session. Each worktree is shown as a group: its name (the primary checkout is marked **Primary** right after it), a subtitle (the branch when renamed, otherwise the directory), and its open tabs beneath. The active session's whole group is highlighted. A filled green dot means a session is open, a **pulsing** green dot means an agent is working in it, a **blue** dot with a halo means an agent is waiting for your answer, a hollow dot means no session, and amber marks running tabs or a deletion in progress. Each tab is listed under the name you gave it, otherwise the title of the terminal or agent in it (omp titles its tab after the conversation); a tab whose agent is waiting for you also says **waiting**. Click an indented tab to focus it. New tabs in a managed session start at its worktree root.
4. Click **+** beside a project's worktree count (its tooltip reads **New worktree from** the base branch). Enter a new branch name and, optionally, a **Display name** (Tab moves to it). Creation runs **in the background**: its output goes to a **Create: …** tab that opens without switching to it. Native Tern notifications announce when it starts and finishes.
5. When the completion notification appears, select the new worktree. On success the **Create: …** tab closes by itself; on failure it stays open showing why (press Enter there to close it). If a hook needs approval, Worktrunk waits in that tab until you answer.
6. Right-click a worktree for **Rename**, **Add to Ice Box**, **Close session**, or **Delete worktree**. Rename sets a friendly Projects label; close and delete ask for confirmation. Close keeps the files; delete removes the directory but keeps the Git branch. Deletion also runs in the background, like creation. Right-click a project's name for **Change base branch**.

Project additions, worktree creation/removal, renames, session closures, and action errors use native Tern notifications rather than banners at the top of Projects. Confirmation controls, form validation, and per-project discovery errors stay inline.

Notification titles name the action, such as **Worktree created** or **Worktree deleted**. Descriptions contain only the affected name or a brief next step. Long names are shortened to 32 Unicode characters, including an ellipsis; their full labels remain in Projects. Failed operations point to their **Create** or **Delete** tab. Other errors give short guidance, with detailed diagnostics in Tern's log.

Click the info icon immediately after the **Projects** heading to open this guide in a rendered Markdown tab. Its tooltip is **How Projects works**. The button reads the README bundled with the installed plugin, so it works offline and when you share or copy the plugin to another machine.

New worktree, Rename, and Change base branch open **in place of the Projects panel**, like a page within it: same position, same width, so the rest of your layout never shifts. Click **← Projects** or press Esc to go back without changes; submitting returns to Projects too. While a form is showing, the Projects shortcut focuses it rather than opening a second panel. Forms support Tab/Shift+Tab, Enter, Escape, arrows, selection, Cmd+A/C, and Unicode text. Validation failures leave the form editable. **↻** discovers externally created/removed worktrees and re-checks pull requests; it spins until every project's worktrees have reloaded (at least one turn). An open navigator also refreshes every 15 seconds, silently.

The navigator is a native pane, not an application-wide sidebar. It opens to the left of the first terminal of a new worktree session, using approximately one-third of the width (rounded to Tern's resize increment). It is not duplicated into every tab. The shortcut returns to that session's existing navigator, even from another tab. Resize its divider using Tern's normal controls; reopening Projects or switching worktrees preserves that session's adjusted width.

**Display names** change only the Projects row, not the Git branch, worktree directory, or Tern session name. For example, keep branch `ALL-2456` and label its row `Fix onboarding`. Set one when creating the worktree, or later with **Rename**. A name given at creation is applied once Worktrunk has created the worktree, even if setup hooks later fail; a rename made while setup is still running takes precedence. Hover the row to see its branch and full path. Names are saved per project/worktree and survive refreshes, session closure, and restarts. Clear the display-name field and save to restore the branch label. Successful deletion through Overseer removes the saved name too.

**Changes at a glance:** an amber **✱** after a worktree's name means it has uncommitted changes (staged, edited, renamed, deleted, or new files). A red **conflicts** badge replaces it while a merge or rebase has unresolved conflicts. Hover the row for the details, refreshed every 15 seconds and on **↻**: branch and path; uncommitted line counts and kinds of change (for example `+509 −2408 · edited, deleted, new files`); commits ahead of and behind the default branch and the upstream (for example `origin: 1 ahead`); the pull request; and the session's tab count and agent state. Lines with nothing to report are left out.

**Ice Box** parks worktrees you aren't working on. Right-click a worktree and choose **Add to Ice Box**: it moves to the bottom of its project with 🧊 in place of its dot, and nothing else changes (its files, branch, and session stay as they are). The **🧊** button beside **↻** hides or shows ice-boxed worktrees across all projects. The worktree you're currently in stays visible even when the Ice Box is hidden. **Remove from Ice Box** puts it back in its usual place. The primary checkout can't be iced. The Ice Box and the show/hide choice survive restarts; deleting a worktree through Overseer also removes it from the Ice Box.

**Agent activity:** the dot pulses while an agent is working in that worktree's session, and turns blue when one has asked you something and is waiting for an answer; waiting wins when a session has both. Tern's own agent blocks, which include omp, report these states directly: omp is **waiting** while its ask prompt is open, and neither working nor waiting between turns. Other agent CLIs run in a plain terminal (`pi`, `claude`, `codex`, `opencode`, `gemini`, `aider`, `amp`, `cursor-agent`, `crush`, `goose`) can only be seen working: they count as working while they report progress to the terminal, and a CLI that doesn't report progress (or hasn't yet, like Claude right after launch) counts as working for as long as it runs. With the system's reduce-motion setting on, a static ring replaces the pulse.

**Pull request badges** appear at the right end of a worktree's row when its branch has a GitHub pull request. They use GitHub's own Octicons and colours: grey draft, green open, purple merged, red closed. Hover for the number and state ("#2435 · Merged"); click to open the PR, following Tern's link setting. If a branch has several PRs, the open one wins, otherwise the most recently updated. PRs are matched by branch name, so merged PRs still show after GitHub deletes their branch. The primary checkout and branches without a PR show no badge.

Each project makes one request through your signed-in `gh`, in the background, at most every 2 minutes, and right away when worktrees are added or removed or you click **↻**. Only projects whose `origin` is on github.com are checked. If a lookup fails (offline, signed out), the last known badges stay; the error is written to Tern's log.

The pull request and info icons are [Primer Octicons](https://primer.style/octicons/) (MIT, `icons/LICENSE`). Tern plugin stylesheets can't load image files, so `icons/generate-css.py` embeds them in `icons.css`; rerun it after replacing an SVG.

## Creation and trust

Overseer runs the equivalent of:

```sh
wt -C /path/to/project switch --create --base master --no-cd new-branch
```

New worktrees branch from the project's base. Overseer detects it when you add the project: local `master`, then the local branch named by `origin/HEAD`, then local `main`, then whatever branch the checkout has checked out. If the checkout is on a detached HEAD with none of those, Overseer asks you to check out a branch and add the project again. To use a different base later, right-click the project's name and choose **Change base branch**; only an existing local branch is accepted, and existing worktrees are unaffected. No fetch, pull, checkout of the primary directory, or forced overwrite occurs.

Creation preserves the terminal's stdin/stdout/stderr. Overseer never supplies `--yes` or `--no-hooks`. Worktrunk handles approvals, blocking `pre-start` hooks, and background hooks normally. Declining approval may still create a worktree **without running project hooks**, as Worktrunk documents.

“Worktree created” means the Worktrunk command returned zero, **not** that every setup task succeeded. Hooks can warn and exit zero, and background hooks can still be running. Some project setup scripts deliberately return zero on partial failures. Because the **Create: …** tab closes automatically on a zero exit, such warnings aren't kept on screen; check the new worktree if a setup step matters. A nonzero command status triggers a native error notification with the tab left open, and partially created worktrees remain discoverable.

The outcome comes from a receipt the helper writes when it finishes, not from the terminal's state. If Tern stops reporting the setup terminal while the helper is still running (for example, after a window restart), Overseer checks the helper's process and keeps waiting. It reports a failure only when that process is gone without having written a receipt.

Arguments are encoded before entering the login shell and decoded only inside Bash, then passed as quoted arguments. Unicode, spaces in paths, quotes, dollar signs, and semicolons are not evaluated as shell code. Creation was exercised through both zsh and Nushell.

## Close and delete

**Close session** stops its running programs and closes its tabs. The worktree stays listed and can be reopened. Locked sessions must be unlocked first. A session with a pending Worktrunk operation cannot be closed through this menu until that operation finishes or is cancelled in its terminal.

**Delete worktree** runs:

```sh
wt -C /path/to/project remove --foreground --no-delete-branch -- /path/to/worktree
```

Deletion runs in a **Delete: …** tab that opens in the background, so you stay where you are; Projects shows the outcome when it finishes, and the tab closes by itself on success. If you delete the worktree you're in, that tab goes to the project's primary checkout session instead (or another session), because the deleted worktree's session closes on success; you then land in the primary checkout session. Worktrunk keeps its normal hook approval prompts and removal hooks, answered in that tab; Overseer never adds `--yes`, `--no-hooks`, or force flags.

The primary checkout cannot be deleted. Uncommitted changes and untracked files block removal. The target's repository identity, branch, and cleanliness are rechecked before invoking Worktrunk. **Ignored files are removed with the directory**; copy anything needed first, and stop programs that are writing into it.

Only a zero exit status with the directory gone triggers closing its managed session. Failures leave the session open and retain the **Delete: …** tab for diagnosis. If the session becomes locked during removal, it is left open with an explicit warning. Cancelling the confirmation, or reloading the plugin before the command starts, does not delete anything.

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

- Adding a project through the macOS folder picker: a folder with a space in its name was added with its current branch as base; a non-repository folder reopened the picker there; cancelling and re-adding a duplicate changed nothing. Discovery of a Git-created linked worktree.
- Separate worktree sessions, root-directory new tabs, and reuse of sessions after plugin reload.
- Editable invalid-branch errors; form draft restoration and cancellation after reload.
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
- Real omp agent blocks: idle, working, and waiting on an ask prompt, reflected in the worktree dot and the tab row (titled after the omp conversation rather than "Projects").
- Creation still worked through the renamed helper with a literal Unicode/shell-metacharacter branch. Detached deletion exercised empty-argument encoding under macOS Bash 3.2.

The helper also passes `bash -n`. Run the ten real Git/Worktrunk regression tests with Python 3:

```sh
python3 -B tests/test_worktree_operation.py -v
```

Tests use temporary repositories, configuration, and approvals. They cover staged/untracked-file protection, primary and foreign-repository rejection, branch changes after confirmation, failing removal hooks, retention of unmerged branches, removal of ignored files, detached worktree removal, creation from the selected base with literal shell metacharacters, and the helper's PID file and completion receipt.

These checks are not a claim of exhaustive compatibility across Tern versions or multiple-window concurrency.
