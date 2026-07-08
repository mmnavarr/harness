# Prismic Setup

## Key References

- **Homepage document ID**: `ZErWzRAAACoAyw6N`
- **Homepage editor**: `https://alliance.prismic.io/builder/pages/ZErWzRAAACoAyw6N`
- **Content API**: `https://alliance.cdn.prismic.io/api/v2`

## Homepage Slice Zones

| Prismic tab | Slice zone field | Theme |
|-------------|-----------------|-------|
| Main | `slices` | Dark (hero area) |
| Light Section | `slices1` | Light (middle) |
| Dark Section | `slices2` | Dark (footer) |

## Finding Experiments in Prismic

### Method 1: Content API Script (Recommended)

Run this in Chrome DevTools console or via `javascript_tool` to find where an experiment lives in any Prismic document (uses `return` which works in DevTools eval context):

```javascript
(async () => {
  const SEARCH_KEY = 'YOUR_FLAG_KEY'; // e.g. 'one_week_acceptance'
  const DOC_ID = 'ZErWzRAAACoAyw6N'; // homepage, or any document ID

  const resp = await fetch('https://alliance.cdn.prismic.io/api/v2');
  const api = await resp.json();
  const ref = api.refs.find(r => r.isMasterRef).ref;
  const docResp = await fetch(
    `https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${ref}&q=[[at(document.id,"${DOC_ID}")]]`
  );
  const doc = await docResp.json();
  const homepage = doc.results[0];
  const results = [];
  for (const [zone, slices] of Object.entries(homepage.data)) {
    if (!Array.isArray(slices)) continue;
    for (const slice of slices) {
      if (!slice.slice_type) continue;
      if (Array.isArray(slice.items)) {
        for (const [i, item] of slice.items.entries()) {
          if (item.experiment_id && String(item.experiment_id).includes(SEARCH_KEY)) {
            results.push({
              zone,
              slice_type: slice.slice_type,
              index: i,
              experiment_id: item.experiment_id,
              ...item
            });
          }
        }
      }
    }
  }
  return JSON.stringify(results, null, 2);
})()
```

**Usage**: Replace `SEARCH_KEY` with the flag key (or partial match). Replace `DOC_ID` to search other pages.

**Important**: The Content API returns only **published** content. Draft changes won't appear until the page is published.

### Method 2: Prismic Builder UI

1. Navigate to the page in Prismic builder
2. Open the correct tab (Main, Light Section, or Dark Section)
3. Expand each slice and check item `experiment_id` fields
4. Use `read_page` accessibility tree to find specific items if the UI won't scroll

## Multi-Page Experiments

Some experiments affect multiple pages (e.g., both homepage and the apply page). When setting up these experiments:

1. **Identify all affected pages** — ask the user or check the experiment brief
2. **Apply the same variant structure** to each page's relevant slices
3. **Use identical `experiment_id` values** across pages so the same flag controls both
4. **Publish all affected pages** together when launching

Known multi-page documents:
- Homepage: `ZErWzRAAACoAyw6N` — `https://alliance.prismic.io/builder/pages/ZErWzRAAACoAyw6N`
- Apply page: `ZqPjNxIAACEA4X7X` — `https://alliance.prismic.io/builder/pages/ZqPjNxIAACEA4X7X`

## Navigating the Prismic Builder

### Scrolling to items
The Prismic builder content panel can be tricky to scroll. If normal scrolling doesn't work:
1. Use `read_page` to get the accessibility tree
2. Find the target element's `ref_id`
3. Use `scroll_to` with that `ref_id`

### Editing experiment_id fields
1. Navigate to the correct page and tab
2. Expand the target slice
3. Find the repeatable item
4. Locate the `experiment_id` text field
5. Clear any existing value and type the new experiment_id
6. Repeat for all variant items

### Publishing
After all edits are saved:
1. Click the "Publish" button (usually top-right of the builder)
2. Confirm the publish action
3. If the browser connection drops, create a new tab group and navigate back to the page
