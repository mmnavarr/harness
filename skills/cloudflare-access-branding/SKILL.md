---
name: cloudflare-access-branding
description: Use when customizing Cloudflare Access login pages, app launcher branding, logos, colors, footer links, app visibility, tags, app grouping, or Access tile appearance for internal tools.
tags: [cloudflare, access, branding, app-launcher]
---

# Cloudflare Access Branding & App Launcher Customization

## When to Use
- Customizing the Cloudflare Access login page or app launcher appearance
- Hiding/showing apps, adding logos, grouping apps with tags

## Key API Endpoints

### Organization Login Page
```
PUT /accounts/{account_id}/access/organizations
```
Fields in `login_design`:
- `background_color` — page bg
- `text_color` — text on page
- `logo_path` — logo URL
- `header_text` — header text
- `footer_text` — footer text

### App Launcher
```
GET /accounts/{account_id}/access/app_launcher
PUT /accounts/{account_id}/access/apps/{app_launcher_id}
```
Discover the app launcher with `GET /accounts/{account_id}/access/app_launcher`, then update the returned app launcher app with `PUT /accounts/{account_id}/access/apps/{app_launcher_id}`. The PUT payload must include `type: "app_launcher"`.
Fields:
- `app_launcher_logo_url` — logo in header bar
- `bg_color` — page background
- `header_bg_color` — header bar background
- `landing_page_design.title` — welcome title
- `landing_page_design.message` — welcome message
- `landing_page_design.image_url` — landing page logo
- `landing_page_design.button_color` — sign-in button color
- `landing_page_design.button_text_color` — button text color
- `footer_links` — array of {name, url} objects

### Per-App Settings
```
PUT /accounts/{account_id}/access/apps/{app_id}
```
- `app_launcher_visible` (boolean) — show/hide from launcher
- `logo_url` — custom tile icon (MUST be square aspect ratio)
- `tags` — array of existing tag name strings for grouping/filtering (for example, `["Tools"]`), not tag objects

### Tags
```
POST /accounts/{account_id}/access/tags  — create tag {"name": "TagName"}
GET /accounts/{account_id}/access/tags   — list existing tags
```
Tags must be created before assigning to apps; assign them by existing tag name string.

## Pitfalls

1. **App launcher text color is NOT controllable via API** — it defaults to black. You MUST use a light `bg_color` or text will be unreadable on dark backgrounds.
2. **Logo URLs must be square** — wide/banner logos will stretch. Use GitHub avatars or square icons.
3. **`dash_sso` app type** (SSO App) requires different PUT payload than `self_hosted` apps — include all original fields.
4. **Login page vs App Launcher** — `login_design` on the org endpoint affects the pre-auth login page. The `app_launcher` endpoint affects the post-auth app grid. Both need separate configuration.
5. **Tags must exist before assignment** — POST to create tags first, then reference them when updating apps.
6. **Animated GIFs work** for logos but may look odd at small sizes; prefer static PNGs for app tiles.

## Alliance-Specific Config (Apr 2026)
- Account ID: `39a4489cfb18c4f43a10ea2da1eb74c6`
- Domain: `alliancexyz.cloudflareaccess.com`
- Brand colors: black (#000000), off-white (#FAF8F8), lime green (#4BE515)
- Static Alliance logo: `https://pbs.twimg.com/profile_images/1980347067898769408/oy9yAKDq_400x400.png`
- Black animated logo: `https://images.prismic.io/alliance-io/aGVsbyBmcm9tIGFsbGlh-alliance-triangle-animation-blk-1-.gif`
- White animated logo: `https://images.prismic.io/alliance-io/aGVsbyBmcm9tIGFsbGlh-alliance-triangle-animation-1-.gif`
- Tag groups: Tools (Metabase, N8N, Notebooks), Eng Tools (Uptime Kuma, Symphony, Infisical), Eng Dashboards (Scout Queues, Scout Bucket)
- Hidden: SSO App, Aria, HubSpot AI, Scout
