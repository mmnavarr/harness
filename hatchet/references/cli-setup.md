# Hatchet CLI setup

Use this when the user needs a CLI profile, the TUI, or read-only run/workflow inspection against Alliance Hatchet.

## Preconditions

- `hatchet` CLI is installed. Check with `hatchet --version` or `hatchet -v`.
- Tailscale/tsmesh DNS can resolve `railway-monorepo`.
- The user has a Hatchet API token. Prefer storing it with `fnox` rather than putting it in shell history.

## Token setup with fnox and mise

The preferred local secret path is:

```bash
fnox set HATCHET_CLIENT_TOKEN -g --provider keychain
```

`-g` is optional. The important part is using the keychain provider so `mise`/`fnox` can inject the token into commands without printing it.

If the token is not visible to the parent shell, execute token-consuming commands inside a `mise exec` shell so expansion happens after injection. Include the API/TLS overrides on `profile add` because the CLI validates the token against Hatchet before saving the profile:

```bash
mise exec -- sh -c 'HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 HATCHET_CLIENT_TLS_STRATEGY=none hatchet profile add --name railway-monorepo --token "$HATCHET_CLIENT_TOKEN"'
```

Avoid commands such as `printenv HATCHET_CLIENT_TOKEN`, `echo $HATCHET_CLIENT_TOKEN`, or logging full profile data with `--show-token`.

## Create or refresh the profile

```bash
mise exec -- sh -c 'HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 HATCHET_CLIENT_TLS_STRATEGY=none hatchet profile add --name railway-monorepo --token "$HATCHET_CLIENT_TOKEN"'
hatchet profile set-default --name railway-monorepo
hatchet profile show --name railway-monorepo
```

`hatchet profile show` does not include the raw token by default; do not add `--show-token`.

Hatchet CLI profiles derive API and gRPC addresses from token claims. This deployment is normally reached from the laptop through tsmesh at `http://railway-monorepo:11744`, so pass explicit overrides during profile creation and command execution if the token embeds internal or stale addresses.

## Read-only command wrapper

Use this shape for routine inspection:

```bash
HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet <command> --profile railway-monorepo --output json
```

Examples:

```bash
HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet workflows list --profile railway-monorepo --output json

HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet runs list --profile railway-monorepo --output json --since 7d --status FAILED

HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet runs get <run-id> --profile railway-monorepo --output json
```

## TUI

```bash
HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet tui --profile railway-monorepo
```

If the user asks to inspect failed jobs interactively, prefer the TUI after first confirming the API route works.
