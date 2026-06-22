# goldscalper-ea Traffic Metrics

Daily snapshot of traffic stats for this repository (`jmac17ba/goldscalper-ea`).

GitHub's Traffic API only retains the last 14 days. A cron'd GitHub Action
(`.github/workflows/traffic.yml`) pulls clones + views every day and accumulates them
into `traffic.json` for the full project history.

> Tooling adapted from [Lum1104/understand-anything-metrics](https://github.com/Lum1104/understand-anything-metrics) (MIT).

## Data shape

`traffic.json`:

```json
{
  "totals": {
    "clones": 0,
    "uniqueClonerDays": 0,
    "peakDailyClones": 0,
    "peakDailyUniqueCloners": 0,
    "views": 0,
    "uniqueVisitorDays": 0,
    "peakDailyViews": 0,
    "peakDailyUniqueVisitors": 0,
    "daysTracked": 0,
    "firstDay": null,
    "lastDay": null
  },
  "clones": [
    { "timestamp": "2026-06-22T00:00:00Z", "count": 12, "uniques": 4 }
  ],
  "views": [
    { "timestamp": "2026-06-22T00:00:00Z", "count": 45, "uniques": 30 }
  ],
  "lastUpdated": "2026-06-22T03:00:00Z"
}
```

It starts empty; the first workflow run fills it from the live API.

### Per-day entries

- `count` — total clones / page views that day.
- `uniques` — unique cloners / visitors that day.

### Totals

Recomputed from the full history every run.

| Field | Meaning |
|---|---|
| `clones` | All-time sum of daily clone counts. Each clone is counted once. |
| `uniqueClonerDays` | Sum of daily-`uniques`. **Not** total unique users — GitHub doesn't expose cloner identity, so the same person cloning on 5 days adds 5 to this number. Useful as a "cloner-engagement-days" proxy. |
| `peakDailyClones` | Highest single-day total clones. |
| `peakDailyUniqueCloners` | Highest single-day unique-cloner count. A lower bound on "ever cloned by N distinct users". |
| `views` / `uniqueVisitorDays` / `peakDailyViews` / `peakDailyUniqueVisitors` | Same idea for page views. |
| `daysTracked` | Length of the `clones` array. |
| `firstDay` / `lastDay` | Range of recorded days (ISO timestamps). |

## How it works

`.github/workflows/traffic.yml` runs daily at 03:00 UTC (also `workflow_dispatch` for
manual triggers). It calls the GitHub Traffic API for this repo, merges the returned
14-day window into the existing history (deduplicated by timestamp, newer wins), and
commits only if anything changed.

The traffic API requires push access, so the workflow uses a PAT stored as the
`TRAFFIC_TOKEN` repo secret (Settings → Secrets and variables → Actions). It will not
run until that secret exists and the workflow is on the default branch.
