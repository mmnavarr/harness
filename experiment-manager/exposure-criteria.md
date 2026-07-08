# Exposure Criteria Setup

All experiments use **custom exposure** with the `$feature_view` event. This must be configured manually in PostHog via Chrome after creating the experiment.

## Standard Exposure Config

- **Event**: `$feature_view`
- **Filter**: `$feature/<flag_key>` → "is set"

## Step-by-Step (Chrome)

1. **Navigate** to the experiment page:
   ```
   https://us.posthog.com/project/33209/experiments/<experiment_id>
   ```

2. **Find the exposure section**: Look for "Experiment exposure" or "Custom exposure" area on the experiment detail page.

3. **Select custom exposure**: Choose `$feature_view` as the exposure event.

4. **Add the filter**:
   - Click "Add filter" or the filter area
   - Search for `$feature/<flag_key>` — e.g., `$feature/one_week_acceptance_2`
   - **Important**: New flags may not appear in search results immediately. If "No results" appears:
     - Try searching for a partial match (e.g., `$feature/one_week`)
     - Look under the "Feature flags" category
     - Click "Show X properties that haven't been seen with this event" to reveal new flags
   - Set the condition to **"is set"**

5. **Save** the exposure criteria.

## Why Custom Exposure Matters

Without custom exposure, PostHog counts every visitor as exposed, diluting experiment results. The `$feature_view` event only fires when a user actually sees the variant content, giving accurate conversion measurements.

## Troubleshooting

- **Flag not appearing in filter search**: The flag is too new and hasn't been seen in any events yet. Use the "show unseen properties" option.
- **Exposure not recording**: Verify the website code emits `$feature_view` with the correct flag key when the experiment content renders.
