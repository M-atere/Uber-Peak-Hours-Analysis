# 🕐 Uber Peak Hours of Operations: A Multi-City SQL Analysis

## 📌 Project Overview

This project analyzes ride-share trip data across four major U.S. cities, **Los Angeles, Houston, New York, and Chicago**, to identify peak operational hours and understand how demand patterns differ by city and zone type.

Rather than using a fixed threshold, peak hours are determined statistically: hours are benchmarked against each city's own mean and standard deviation, making the classification adaptive and data-driven.

This is the second project in this portfolio, building on the same dataset used in the [Uber Revenue Analysis](https://github.com/M-atere/Uber-Revenue-Analysis). Where that project examined *who* earns the most and *why*, this one examines *when* the platform is most active.

---

## 🗃️ Dataset

The analysis uses the `trips` table joined with `locations` for geographic context.

**Key columns used:**

| Column | Description |
|---|---|
| `requested_at` | Datetime when the trip was requested |
| `status` | `completed`, `in_progress`, or `cancelled` |
| `pickup_location_id` | Links to `locations` for city and zone type |

**Zone types:** `residential`, `commercial`, `airport`, `transit_hub`

---

## 🔍 The Investigation

### 1. Hour Extraction & Status Breakdown

Trip timestamps follow `YYYY-MM-DD HH:MM:SS`. Only the **hour component** is needed, extracted via `EXTRACT(HOUR FROM requested_at)`. A single CTE captures all three statuses -- completed, in-progress, and cancelled, in one pass using conditional aggregation, then surfaces the top 5 hours per status via `UNION ALL`.

**Top findings across all statuses:**

| Status | Peak Hour | Trips |
|---|---|---|
| Completed | 18:00 | 754 |
| Cancelled | 19:00 | 154 |
| In Progress | 16:00 | 14 |

> ⚠️ The in-progress counts are notably small compared to completed trips. Unusual clustering at specific hours (16:00, 14:00, 21:00) may indicate system downtime or driver availability gaps rather than genuine demand.

---

### 2. Statistical Classification of Peak Hours

Instead of a fixed cutoff, peak hours are defined relative to the dataset's own distribution:

| Metric | Value |
|---|---|
| Average trips / hour | 701.13 |
| Standard deviation | 26.95 |
| Normal range | 674.18 – 728.08 |

Hours are classified using a `CASE` statement joined against a metrics CTE:

- ⬆️ **Above Average Peak** → `total_trips > avg + std_dev` (> 728.08)
- ➡️ **Normal Average** → within the range
- ⬇️ **Below Average Low** → `total_trips < avg - std_dev` (< 674.18)

**Global peak hours (completed trips only):**

| Hour | Total Trips | Classification |
|---|---|---|
| 18:00 | 754 | ⬆️ Above Average Peak |
| 14:00 | 749 | ⬆️ Above Average Peak |
| 09:00 | 732 | ⬆️ Above Average Peak |
| 08:00 | 731 | ⬆️ Above Average Peak |

**Possible explanations:**
- **18:00** — End of workday and school dismissal; people heading home or out for the evening
- **08:00–09:00** — Morning commute; people leaving home or wrapping up night shifts
- **14:00** — Lunch breaks or early school dismissals

---

### 3. City-Level Breakdown (Macro → Micro)

A `VIEW` (`zones`) is created joining `trips` and `locations` to simplify repeated city-level queries. The city analysis shifts from a global average to **window functions**, benchmarking each city against its own distribution:

```sql
ROUND(AVG(total_trips) OVER(PARTITION BY city), 2) AS city_avg,
ROUND(STDDEV_SAMP(total_trips) OVER(PARTITION BY city), 2) AS city_dev
```

This ensures each city's peak hours reflect local demand patterns, not a global baseline.

**City highlights:**

| City | Top Zone | Peak Hour | Character |
|---|---|---|---|
| Los Angeles | Residential | 05:00 | Early morning activity dominate |
| Houston | Commercial | 14:00 | Commercial zones drive all above-average hours |
| New York | Residential | 08:00 | Widest spread, residential zones peak almost every hour |
| Chicago | Residential | 02:00 | Strong late-night and early-morning demand |

> Notable: Transit hubs rank below average in all four cities despite being high-footfall zones, worth investigating.

---

## 💡 Key Takeaways

- Statistical classification (mean ± std dev) is more robust than arbitrary thresholds; it adapts to the data rather than imposing assumptions on it.
- Zone type matters as much as the hour itself. The same peak hour carries different implications in a residential vs. commercial area.
- City character shows up in the data: Houston's commercial dominance, New York's residential spread, Chicago's late-night peaks, and LA's early-morning activity all reflect real urban patterns.
- In-progress trip clustering at unusual hours is a signal worth flagging, not a demand insight but a potential operational one.

---

## 🛠️ SQL Techniques Used

- `EXTRACT(HOUR FROM ...)` — datetime decomposition
- Conditional aggregation — `COUNT(CASE WHEN status = '...' THEN 1 END)`
- **CTEs** (`WITH` clauses) — modular, readable query design
- `UNION ALL` — combining ranked results across multiple status types
- `STDDEV_SAMP()` — sample standard deviation
- `CROSS JOIN` — broadcasting scalar metrics across all rows
- **Window functions** — `AVG() OVER(PARTITION BY city)` for city-relative benchmarking
- `CASE` statements — conditional classification
- **Views** — simplifying repeated joins for geographic queries

---

## 🗂️ Repository Structure

```
Uber-Peak-Hours-Analysis/
│
├── sql_scripts/
│   └── peak_hours_analysis.sql     # Full analysis script
│
├── visualizations/
│   └── Peak_Hour_Performance.xlsx  # Output: global + per-city breakdowns
│
└── README.md
```

---

## 📂 Data Provenance

- **Data Source:** [Kaggle](https://www.kaggle.com/datasets/rockyt07/uber-sql-database?select=schema.sql)
- **Database:** MySQL
- **Related Project:** [Uber Revenue Analysis](https://github.com/M-atere/Uber-Revenue-Analysis)
