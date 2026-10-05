# Tern plugins

Plugins for [Tern](https://docs.stencil.so/tern/).

| Plugin | What it does |
| --- | --- |
| [`overseer/`](overseer/) | Projects panel for local Git repositories and [Worktrunk](https://worktrunk.dev) worktrees. Each worktree gets its own Tern session. |
| [`review-queue/`](review-queue/) | Pull requests requesting your review, refreshed every two minutes through the GitHub CLI. |

## Install

Requirements: desktop Tern, Git, Bash, and Worktrunk (`wt`) on your `PATH`.

```sh
git clone https://github.com/mmnavarr/harness.git ~/code/harness
/Applications/Tern.app/Contents/MacOS/tern plugin link ~/code/harness/tern/overseer
```

`link` loads the plugin from your clone, so a `git pull` picks up updates and Tern reloads it automatically. To install a separate copy that doesn't change when you pull, use `tern plugin install` instead.

Then press **Cmd+Option+Shift+P**, or run **Open Projects** from the command palette. Click the **(i)** button next to **Projects** for the full guide.

Uninstall:

```sh
/Applications/Tern.app/Contents/MacOS/tern plugin unlink overseer
```

Removing the plugin leaves your worktrees and open sessions alone.

## Review Queue

Requires the GitHub CLI (`gh`) on the host running your panes, signed in with `gh auth login`.
The plugin is the official [Tern SDK example](https://docs.stencil.so/tern/examples/review-queue.md).

```sh
/Applications/Tern.app/Contents/MacOS/tern plugin link ~/code/harness/tern/review-queue
```

Press **Cmd+Option+Shift+R**, or run **Open review queue** from the palette.
Use **j/k** or the arrow keys to move, **Enter** to open a PR, **r** to refresh,
and **d** to toggle drafts. Drafts are hidden initially.

To remove it:

```sh
/Applications/Tern.app/Contents/MacOS/tern plugin unlink review-queue
```
