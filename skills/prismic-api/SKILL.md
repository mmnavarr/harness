---
name: prismic-api
description: Query and manage Prismic CMS content, custom types, and slices via HTTP APIs with secure authentication via 1Password
---

# Prismic CMS API Skill

Query and manage Prismic CMS content, custom types, and slices using the Prismic HTTP APIs.

## Overview

This skill enables you to:
- Query documents from the Content API
- Get repository metadata and refs
- Manage custom types (list, create, update, delete)
- Manage shared slices (list, create, update, delete)
- Access document tags and languages

## Repository Configuration

- **Repository Name**: `alliance`
- **Content API**: `https://alliance.cdn.prismic.io/api/v2`
- **Custom Types API**: `https://customtypes.prismic.io`
- **Migration API**: `https://migration.prismic.io`

## Authentication Setup

### 1. Generate .env file from 1Password

```bash
SKILL_DIR=.agents/skills/prismic-api
op inject -i $SKILL_DIR/.env.example \
  -o $SKILL_DIR/.env \
  --account defialliancellc.1password.com --force
```

### 2. Source the environment variables

**IMPORTANT**: NEVER print or cat the contents of .env file. Always source it instead:

```bash
source .agents/skills/prismic-api/.env
```

## Reusable Scripts

**IMPORTANT: Prefer these scripts over inline curl commands.** They handle auth and ref setup automatically.

Located in `.agents/skills/prismic-api/scripts/`. All scripts accept optional jq filters.

| Script | Usage | Description |
|--------|-------|-------------|
| `get-homepage.sh` | `./get-homepage.sh [jq-filter]` | Get homepage document data |
| `get-experiment.sh` | `./get-experiment.sh <uid> [jq-filter]` | Get experiment by UID |
| `list-experiments.sh` | `./list-experiments.sh [jq-filter]` | List all experiments with status |
| `query-document.sh` | `./query-document.sh <type> [uid] [jq-filter]` | Query any document by type/UID |
| `search-content.sh` | `./search-content.sh <term> [jq-filter]` | Full-text search across documents |
| `list-custom-types.sh` | `./list-custom-types.sh [type-id]` | List or get custom type definitions |
| `list-slices.sh` | `./list-slices.sh [slice-id]` | List or get shared slice definitions |

### Examples

```bash
SCRIPTS=.agents/skills/prismic-api/scripts

# Get homepage meta title
$SCRIPTS/get-homepage.sh '.metaTagTitle'

# List homepage slice types
$SCRIPTS/get-homepage.sh '.slices[] | {slice_type, id}'

# Get experiment details
$SCRIPTS/get-experiment.sh headline-crypto-ai-2

# List all enabled experiments
$SCRIPTS/list-experiments.sh 'select(.enabled == true)'

# Search for content mentioning "crypto"
$SCRIPTS/search-content.sh "crypto"
```

## Content API

The Content API is used to query published documents.

### Get Repository Metadata (including refs)

Before querying documents, you need to get the current `ref` (version identifier):

```bash
curl -s "https://alliance.cdn.prismic.io/api/v2" | jq '.'

# Get the master ref (most common)
PRISMIC_REF=$(curl -s "https://alliance.cdn.prismic.io/api/v2" | jq -r '.refs[] | select(.isMasterRef == true) | .ref')
echo "Master ref: $PRISMIC_REF"
```

### Query Documents

**Basic query (all documents):**
```bash
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}" | jq '.'
```

**Query by document type:**
```bash
# URL encode the query: [[at(document.type,"page")]]
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=%5B%5Bat(document.type%2C%22page%22)%5D%5D" | jq '.results[] | {id, type, uid}'
```

**Query by UID:**
```bash
# Get document with uid "about"
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=%5B%5Bat(my.page.uid%2C%22about%22)%5D%5D" | jq '.results[0]'
```

**With pagination:**
```bash
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&page=1&pageSize=20" | jq '.'
```

**With ordering:**
```bash
# Order by last publication date descending
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&orderings=%5Bdocument.last_publication_date%20desc%5D" | jq '.'
```

**For private repositories (add access token):**
```bash
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&access_token=${PRISMIC_ACCESS_TOKEN}" | jq '.'
```

### Query Parameters Reference

| Parameter | Description | Example |
|-----------|-------------|---------|
| `ref` | **Required**. Version identifier | `YHhVOBAAACcACRyo` |
| `access_token` | For private repositories | Your token |
| `q` | Filter query (URL encoded) | `[[at(document.type,"page")]]` |
| `page` | Page number (default: 1) | `2` |
| `pageSize` | Results per page (default: 20, max: 100) | `50` |
| `orderings` | Sort order | `[document.last_publication_date desc]` |
| `lang` | Filter by locale | `en-us` |
| `fetch` | Select specific fields | `page.title,page.body` |
| `fetchLinks` | Include linked document fields | `author.name` |
| `after` | Cursor for pagination | Document ID |

### Filter Query Syntax

Queries use Prismic's predicate syntax. Common predicates:

```
[[at(document.type, "page")]]              # Exact type match
[[at(my.page.uid, "about")]]               # Exact field match
[[any(document.type, ["page", "essay"])]]  # Multiple values
[[fulltext(document, "search term")]]       # Full-text search
[[has(my.page.featured)]]                  # Field exists
[[missing(my.page.featured)]]              # Field doesn't exist
```

**URL encoding tip:** Use `jq -Rr @uri` to encode queries:
```bash
QUERY='[[at(document.type,"essay")]]'
ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}"
```

## Custom Types API

The Custom Types API manages content models. Requires authentication.

### List All Custom Types

```bash
curl -s -X GET "https://customtypes.prismic.io/customtypes" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.[] | {id, label, repeatable}'
```

### Get Specific Custom Type

```bash
curl -s -X GET "https://customtypes.prismic.io/customtypes/page" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.'
```

### Create Custom Type

```bash
curl -s -X POST "https://customtypes.prismic.io/customtypes/insert" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "blog_post",
    "label": "Blog Post",
    "repeatable": true,
    "status": true,
    "json": {
      "Main": {
        "title": {
          "type": "StructuredText",
          "config": {
            "label": "Title",
            "single": "heading1"
          }
        },
        "uid": {
          "type": "UID",
          "config": {
            "label": "UID"
          }
        }
      }
    }
  }'
```

### Update Custom Type

```bash
curl -s -X POST "https://customtypes.prismic.io/customtypes/update" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "blog_post",
    "label": "Blog Post (Updated)",
    "repeatable": true,
    "status": true,
    "json": { ... }
  }'
```

### Delete Custom Type

```bash
curl -s -X DELETE "https://customtypes.prismic.io/customtypes/blog_post" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}"
```

## Shared Slices API

Manage reusable content slices.

### List All Slices

```bash
curl -s -X GET "https://customtypes.prismic.io/slices" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.[] | {id, name}'
```

### Get Specific Slice

```bash
curl -s -X GET "https://customtypes.prismic.io/slices/hero_section" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.'
```

### Create Slice

```bash
curl -s -X POST "https://customtypes.prismic.io/slices/insert" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "feature_card",
    "type": "SharedSlice",
    "name": "FeatureCard",
    "variations": [
      {
        "id": "default",
        "name": "Default",
        "primary": {
          "title": {
            "type": "StructuredText",
            "config": {
              "label": "Title",
              "single": "heading2"
            }
          }
        },
        "items": {},
        "imageUrl": ""
      }
    ]
  }'
```

### Update Slice

```bash
curl -s -X POST "https://customtypes.prismic.io/slices/update" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{ ... slice definition ... }'
```

### Delete Slice

```bash
curl -s -X DELETE "https://customtypes.prismic.io/slices/feature_card" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}"
```

## Migration API

The Migration API allows creating, updating, and publishing documents programmatically. Uses a different token than the Content API.

**Base URL**: `https://migration.prismic.io`

### Create a Document

```bash
curl -s -X POST "https://migration.prismic.io/documents" \
  -H "Authorization: Bearer ${PRISMIC_MIGRATION_TOKEN}" \
  -H "x-api-key: ${PRISMIC_MIGRATION_TOKEN}" \
  -H "repository: alliance" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My New Document",
    "type": "page",
    "uid": "my-new-page",
    "lang": "en-us",
    "data": {
      "title": [{"type": "heading1", "text": "My Page Title", "spans": []}],
      "slices": []
    }
  }'
```

### Update a Document

```bash
curl -s -X PUT "https://migration.prismic.io/documents/{document_id}" \
  -H "Authorization: Bearer ${PRISMIC_MIGRATION_TOKEN}" \
  -H "x-api-key: ${PRISMIC_MIGRATION_TOKEN}" \
  -H "repository: alliance" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Document",
    "uid": "my-new-page",
    "data": {
      "title": [{"type": "heading1", "text": "Updated Title", "spans": []}],
      "slices": [...]
    }
  }'
```

### Add a Slice to an Existing Document

To add a slice (e.g., FAQ/Accordion) to a document:

1. First, get the current document data from Content API
2. Modify the slices array
3. Push the update via Migration API

```bash
# Step 1: Get current document
PRISMIC_REF=$(curl -s "https://alliance.cdn.prismic.io/api/v2" | jq -r '.refs[] | select(.isMasterRef == true) | .ref')
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=%5B%5Bat(document.id%2C%22YOUR_DOC_ID%22)%5D%5D" > /tmp/current_doc.json

# Step 2: Prepare updated data with new slice
# (modify the slices array in the data)

# Step 3: Push update
curl -s -X PUT "https://migration.prismic.io/documents/YOUR_DOC_ID" \
  -H "Authorization: Bearer ${PRISMIC_MIGRATION_TOKEN}" \
  -H "x-api-key: ${PRISMIC_MIGRATION_TOKEN}" \
  -H "repository: alliance" \
  -H "Content-Type: application/json" \
  -d @/tmp/updated_doc.json
```

### Example: Add Accordion/FAQ Slice

```bash
# Accordion slice structure (slice_type: "faq")
{
  "slice_type": "faq",
  "slice_label": null,
  "variation": "default",
  "version": "initial",
  "primary": {
    "title": "Frequently Asked Questions"
  },
  "items": [
    {
      "experiment_id": null,
      "title": "Question 1?",
      "content": [
        {"type": "paragraph", "text": "Answer to question 1.", "spans": []}
      ]
    },
    {
      "experiment_id": null,
      "title": "Question 2?",
      "content": [
        {"type": "paragraph", "text": "Answer to question 2.", "spans": []}
      ]
    }
  ]
}
```

### Migration API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/documents` | POST | Create a new document |
| `/documents/{id}` | PUT | Update an existing document |
| `/documents/{id}` | DELETE | Delete a document |

### Authentication Note

The Migration API uses a **JWT token** (different from the Content API access token):
- Use both `Authorization: Bearer` and `x-api-key` headers
- Token is stored in 1Password as `PRISMIC_MIGRATION_TOKEN`

## Common Workflows

### Export All Custom Types to Files

```bash
# Create output directory
mkdir -p /tmp/prismic-types

# Export all custom types
curl -s -X GET "https://customtypes.prismic.io/customtypes" \
  -H "repository: alliance" \
  -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | \
jq -c '.[]' | while read -r type; do
  id=$(echo "$type" | jq -r '.id')
  echo "$type" | jq '.' > "/tmp/prismic-types/${id}.json"
  echo "Exported: ${id}"
done
```

### Get All Document UIDs by Type

```bash
# Get all essay UIDs
PRISMIC_REF=$(curl -s "https://alliance.cdn.prismic.io/api/v2" | jq -r '.refs[] | select(.isMasterRef == true) | .ref')

curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=%5B%5Bat(document.type%2C%22essay%22)%5D%5D&pageSize=100" | \
jq -r '.results[] | .uid'
```

### Get Document by ID

```bash
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=%5B%5Bat(document.id%2C%22YourDocumentId%22)%5D%5D" | jq '.results[0]'
```

### Search Documents by Full Text

```bash
SEARCH_QUERY='[[fulltext(document, "blockchain")]]'
ENCODED=$(echo -n "$SEARCH_QUERY" | jq -Rr @uri)
curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}" | jq '.results[] | {uid, type}'
```

## API Endpoints Summary

### Content API (`https://alliance.cdn.prismic.io/api/v2`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Repository metadata (refs, types, languages) |
| `/documents/search` | GET | Query documents |

### Custom Types API (`https://customtypes.prismic.io`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/customtypes` | GET | List all custom types |
| `/customtypes/{id}` | GET | Get specific custom type |
| `/customtypes/insert` | POST | Create custom type |
| `/customtypes/update` | POST | Update custom type |
| `/customtypes/{id}` | DELETE | Delete custom type |
| `/slices` | GET | List all shared slices |
| `/slices/{id}` | GET | Get specific slice |
| `/slices/insert` | POST | Create slice |
| `/slices/update` | POST | Update slice |
| `/slices/{id}` | DELETE | Delete slice |

### Migration API (`https://migration.prismic.io`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/documents` | POST | Create a new document |
| `/documents/{id}` | PUT | Update an existing document |
| `/documents/{id}` | DELETE | Delete a document |

## Error Handling

### Common HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Process response |
| 201 | Created | Resource created successfully |
| 204 | No Content | Update/delete successful |
| 401 | Unauthorized | Check access token |
| 404 | Not Found | Check resource ID |
| 409 | Conflict | Resource already exists |
| 422 | Unprocessable | Invalid request body or ID doesn't exist |

### Save Responses Before Parsing

Always save API responses to a file before parsing with jq:

```bash
# Save response first
curl -s "https://alliance.cdn.prismic.io/api/v2" > /tmp/prismic_response.json

# Check response
cat /tmp/prismic_response.json

# Parse if valid JSON
cat /tmp/prismic_response.json | jq '.refs[0]'
```

## Important Limitations

### Slice Zone Configuration Requires Slice Machine

Adding a new slice type to a custom type's slice zone (e.g., allowing the `tweets` slice in the Homepage's "Dark Section") **cannot be done via the Custom Types API**. This must be done through the **Slice Machine UI** (`npx @slicemachine/init` or the local Slice Machine dev server).

The Migration API will reject documents that contain slices not allowed in their slice zone with an error like:
```
"Slice 'tweets' not found in this slice zone in the document's custom type"
```

**Workflow:** If you need to add a slice to a zone where it's not currently allowed:
1. Ask the user to enable it via Slice Machine
2. Then proceed with the Migration API to update the document content

### Custom Types API Authentication

The Custom Types API requires the **Migration API token** (not the Content API access token). Use the token from `op://Engineering/fmslrrwsa24oxuerx4kpdy2te4/credential`.

## Security Notes

- Access tokens are stored securely in 1Password
- Never commit tokens to git
- Use the `--account defialliancellc.1password.com` flag with op commands
- The Content API is public for read operations; Custom Types API requires authentication

## Related Resources

- [Prismic REST API Docs](https://prismic.io/docs/rest-api-technical-reference)
- [Prismic Custom Types API](https://prismic.io/docs/custom-types-api)
- Local Prismic config: `apps/website/slicemachine.config.json`
- CMS package: `packages/cms`
