# Tern plugins

Plugins for [Tern](https://docs.stencil.so/tern/).

| Plugin | What it does |
| --- | --- |
| [`overseer/`](overseer/) | Projects panel for local Git repositories and [Worktrunk](https://worktrunk.dev) worktrees. Each worktree gets its own Tern session. |

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
