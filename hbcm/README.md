# HBCM notebooks

Heron Bay Capital Management additions to this FactSet SDK reference mirror. Nothing here
is vendor code — everything under `hbcm/` is ours, and nothing under `code/`, `specs/`,
`config/`, or `docs/` is modified, so upstream syncs stay clean.

## `notebooks/`

Fabric **Python** notebook templates (import via *Workspace → Import → Notebook*). They
target the `HBCM - Production` workspace and the `hbcm_datahub` lakehouse.

| Notebook | What it does |
|---|---|
| `spar_composite_returns_template.ipynb` | SPAR Engine returns for the four GIPS composites (LC, SMID, LCS, CONC) vs. their benchmarks, gross/net toggle, seven SPAR components ("tiles"), as-of `0CQ` → `factset.spar_composite_returns` |
| `pa_weights_characteristics_template.ipynb` | **Placeholder.** PA Engine holdings snapshot at `0CQ`, single frequency. Weights use `GROUPSALL`, so sector weights (port/bench/active) and security-level weights for top-N come from one call, split into `factset.pa_sector_weights` and `factset.pa_security_weights`; characteristics use `GROUPS`. Write step disabled until the grain discriminator and account column are confirmed against real output. |

### Benchmarks

| Group | Benchmark | Composites |
|---|---|---|
| `r1000` | Russell 1000 | LC, LCS |
| `r2500` | Russell 2500 | SMID |
| `r3000` | Russell 3000 | CONC |

Both notebooks define these once and reference them per strategy, so the two R1000
composites cannot drift onto different benchmarks. In the PA notebook the grouping does
double duty: units are built per benchmark group, which means each unit carries exactly one
benchmark and the account↔benchmark pairing question never arises.

### The document path is most of the config

`SPARComponent` and `PAComponent` both expose the accounts and benchmarks **saved in the
document** — SPAR's carry `id` + `returntype` + `prefix`, PA's carry `id` +
`holdingsmode`, and PA's also carry `dates` and a `snapshot` flag. So a document path plus
the component names is enough to read out the account ids, prefixes, return types and
benchmark ids rather than hand-transcribing them from the workstation. Both notebooks have
a cell that prints them as a paste-ready block.

### `asof_date` is the vintage key — one auditable bundle per quarter

Every table both notebooks write carries the same `asof_date` (`YYYYMMDD`), so a quarter's
output is a single bundle you can audit and reproduce as a unit. Two tables make that usable:

- **`factset.vintage_manifest`** — one row per vintage × table, with row counts, which
  notebook wrote it and when.
- **`factset.dim_vintage`** — one row per vintage with `is_complete` (all four fact tables
  present) and **`is_latest_complete`**.

**Point Power BI at `is_latest_complete`, not `is_latest`.** A vintage where PA landed but
SPAR failed is present but incomplete, and consuming it would show this quarter's holdings
against last quarter's returns — which looks entirely plausible. `dim_vintage` is rebuilt
from the full manifest on every run, so whichever notebook finishes last computes
completeness correctly with no ordering assumption beyond both having run.

### FactSet's numbers are precalculated — nothing here derives them

PA and SPAR return values already aggregated, compounded and annualised at every grain they
publish. These notebooks reshape and type them for display and recompute none of them. The
only arithmetic anywhere is on **dates** and **row counts**, neither of which is a reported
number; where one grain's total is printed beside another's it is labelled reconciliation,
printed only, never written, and the engine's value wins.

Two rules follow into the semantic model:

- **Never `SUM` or `AVERAGE` a return across periods in DAX.** Select the precalculated value
  for the grain on display — that is what the multi-horizon, calendar-year and cumulative
  tiles are for. Compounding monthly returns in DAX will disagree with FactSet, and FactSet is
  the number that goes in front of a client.
- **Never sum a weight across grains.** Sector totals from the sector rows, holdings detail
  from the security rows.

### Horizons are auto-hidden where the history does not exist

A "5 Year" figure for a composite with one year of history renders as a real number, so SPAR
suppresses it rather than flagging it. Months of history come from the inception confirmed off
the time-series responses, so the rule adapts as each composite ages.

- Horizon **columns** invalid for one strategy are blanked for that strategy; columns no
  strategy supports are dropped entirely.
- Horizon **rows**, where a component lays them out that way, are dropped per strategy.
- `YTD` / `QTD` / `MTD` / `ITD` / "Since Inception" / "Cumulative" are always valid — defined
  by whatever history exists rather than requiring a fixed span.
- Columns STACH marks `is_hidden` are dropped as well; that's the engine's own decision.

Suppression withholds, never recalculates — surviving values are identical to what the engine
returned. Blanked and dropped counts land in `factset.factset_run_log`, so the quarter LC's
5-year figure first appears is visible in the log rather than a surprise in a report.

### STACH parsing is schema-driven, not name-driven

The notebooks read each table's own column definitions out of the STACH package rather than
guessing from column names or sniffing values:

- the declared column **`type`** decides date vs numeric vs text, so a component that calls
  its date column "Period End" needs no configuration
- **`is_dimension`** protects identifiers, so an FSYM perm id or a zero-padded code is never
  coerced to a float
- **`null_format`** is the exact token meaning "no value" for *that* column, instead of a
  global guess at `--` / `N/A`
- **`group_level`** (from `CellDetail`) is the authoritative grain discriminator for
  `GROUPSALL`, replacing the earlier heuristic of hunting for a level column or a null
  security id

Columns with no declared type fall back to sniffing and are **reported**, so an undeclared
measure is visible rather than quietly landing as text.

### `strategy_code` is the join key everywhere

A 2–4 character internal code — `LC`, `LCS`, `SMID`, `CONC` — is the single join key across
every PA and SPAR table, because the semantic model is filtered to one strategy at a time.
Both notebooks declare the canonical set and its labels, assert their own config matches, and
assert every landed row's code is present, correctly formatted and known. A null or off-spec
code doesn't fail loudly downstream — it produces a row that silently vanishes from every
strategy-filtered visual, which is worse than an error.

`factset.dim_strategy` is emitted by the PA notebook as the dimension to filter on, carrying
the label, PA account, holdings mode and benchmark per strategy.

### The same security in more than one strategy is expected — plan for it

LC and LCS are both large-cap, so they hold many of the same names. Consequences:

- **`fsym_perm_id` is not a unique key** in `pa_security_weights`. The real grain is
  `asof_date` × `strategy_code` × `fsym_perm_id`, and that uniqueness is asserted before the
  write — a genuine duplicate *within* one strategy would make a relationship fan out and
  weights double, which shows up as plausible-but-wrong numbers rather than an error.
- A security dimension must be **many-to-one**, and `strategy_code` must be in filter context
  before summing any weight. Sum without it and you sum across strategies.
- The notebook reports how many securities are shared and by which strategies, plus the
  portfolio-weight total per strategy (expect ≈100), which is the check that catches a bad
  grain split or an over-aggressive benchmark-only filter.

### Misalignment checks the notebooks run

- **The two monthly SPAR tiles are cross-checked.** `cumulative_monthly` and
  `monthly_raw_returns` are two views of the same monthly stream, so their first period, last
  period and period count must match per strategy and basis. A disagreement means a
  component's saved date range is overriding the request, or a call returned a truncated
  series — either way the two tiles would tell different stories about one composite.
- **Gross and net period counts** must match within a strategy, or a gross-vs-net comparison
  is off by the missing months.
- **Horizon rows that exceed a strategy's history are flagged** — a "5 Year" figure for a
  composite with three years of data is meaningless, not merely empty, and looks like a real
  number in a visual.
- **Partial first calendar years are flagged** — a composite that launched mid-year has a stub
  in its inception year's calendar-year row, not a full-year return.

### Consuming from Power BI — the point of all of this

Both notebooks land **typed** tables so Power Query needs essentially nothing: measures
arrive as `Float64`, dates as real dates. If a report ever needs
`Table.TransformColumnTypes` on a measure, that's a defect here, not something to fix in M —
fix it once at the source rather than in every report.

| Table | Grain |
|---|---|
| `factset.spar_composite_returns` | `asof_date` x `tile` x `strategy_code` x `fee_basis` x the component's own row axis |
| `factset.pa_sector_weights` | `asof_date` x `strategy_code` x sector |
| `factset.pa_security_weights` | `asof_date` x `strategy_code` x `fsym_perm_id` (held names only) |
| `factset.pa_characteristics` | `asof_date` x `strategy_code` x group |
| `factset.factset_run_log` | one row per run, append-only |
| `factset.dim_strategy` | one row per strategy — the dimension to filter on |
| `factset.dim_vintage` | one row per vintage, with `is_latest_complete` |
| `factset.vintage_manifest` | one row per vintage x table, with row counts |

Two columns carry the as-of deliberately: `asof_date` is a `YYYYMMDD` string used by the
Delta delete predicate, and **`asof_date_iso` is the real date** — model on that one.

The three PA weight tables are separate because **PA supplies precalculated weights at every
grain**. A sector row's weight already equals the sum of its securities', so a single shared
table would double-count on any unfiltered `SUM`. Never aggregate one grain to derive
another; if a sum disagrees with the sector row, the sector row wins.

### Quarterly refresh, in order

1. **PA notebook** — resolves `0CQ` and publishes the absolute date SPAR reads.
2. **SPAR notebook.**
3. **Re-frame the Direct Lake semantic model** — until it's re-framed it serves last
   quarter's numbers.
4. **Then** any `VACUUM`. Never before framing: vacuuming files a framed model still points
   at gives users query errors on missing files. Always write → frame → vacuum.

Both notebooks are re-runnable — each write deletes the current `asof_date` before appending,
so a repeat replaces the quarter rather than doubling it, and prior quarters are untouched.

### Benchmarks differ by engine, on purpose

| Engine | Benchmark | Why |
|---|---|---|
| **SPAR** | official Russell index return streams | returns-based; needs only a return series |
| **PA3** | **iShares tracking ETFs** — IWB / SMMD / IWV | holdings-based; needs constituents, and HBCM isn't entitled to official Russell constituent data |

**The two are therefore measured against different benchmarks.** An ETF differs from its
index by expense ratio, cash drag, sampling and timing, so PA active weights will not tie
exactly to SPAR relative returns. That gap is expected — but the two must never be presented
as though they shared a benchmark. The PA notebook checks each component's *saved* benchmark
and warns if one is pointed at an official index, since that would either 403 on entitlement
or silently return no constituents.

### Fee basis is per tile, not global

Performance tiles carry **both** gross and net, since the SEC Marketing Rule requires net
alongside any gross presentation. Risk statistics and peer tables default to **gross only** —
risk stats aren't returns, and peer universes are conventionally gross, so ranking a net
return against a gross universe isn't like-for-like. That peer default is a compliance
judgement rather than a technical one and is a one-word change per tile. 44 SPAR units
rather than 56.

### Dates are dynamic in the request, absolute in the data

`0CQ` is what gets **sent**, so the scheduled job needs no maintenance as quarters roll. The
absolute date PA resolves is what **labels** every row. PA sends no `startdate` at all —
optional in 4.0.0 and meaningless at `Single` frequency.

SPAR's inception tiles set `useeachportfolioinception`, so the **engine** starts each strategy
at its own earliest available monthly data; nothing is configured and nothing is maintained.
The actual window is then read back from each time-series response — per tile × strategy ×
basis, min/max date and period count — which confirms the real inception, confirms the as-of
(max date), flags a mismatch against the `0CQ` label, and catches gross and net series with
unequal period counts.

### PA resolves `0CQ`, and that answer is used everywhere

SPAR Engine has no `DatesApi`; PA does. So `convert_pa_dates_to_absolute_format` turns
`0CQ` into a real `YYYYMMDD`, and **that absolute date is what both notebooks send and what
labels every row** — no locally computed guess reaches the data, and the request is
identical on replay instead of drifting as quarters roll.

The PA notebook publishes its resolved date to `Files/raw/_asof/<relative>.json`; the SPAR
notebook reads that first, falls back to calling PA itself (which needs one PA component id
and one PA account, configured as `PA_PROBE_*` and used for nothing else), and only then to
a computed quarter end — recording which source it used either way.

Note the date endpoint requires `enddate` **and** `componentid` **and** `account`, so it
runs after component resolution, not before.

### Everything is logged to `factset.factset_run_log`

Both notebooks append one row per run: calculation ids, `X-DataDirect-Request-Key`,
`X-FactSet-Api-Request-Key`, rate-limit headers, per-unit status and errors, SDK versions,
resolved vs. computed as-of dates, component ids / names / paths / currency / snapshot
flags, and row counts. Request keys are what FactSet support needs to pull the exact
request, and they exist only at call time — unlogged, they're gone.

### Component ids are resolved by name, every run

Neither notebook hardcodes a component id. Re-saving a component in the workstation can
mint a new id, and a stale id fails as a bare 400 with nothing pointing at the id as the
cause. So the component's **workstation name** is the contract: each run looks up
name → id and fails loudly if a name is absent or ambiguous. An optional
`pinned_componentid` per tile turns a changed id into a visible warning, since a re-saved
component may also have had its columns changed.

### Shared conventions

- **Credentials** come from a separate `HBCM_Config` notebook in the same workspace, pulled
  in with `%run HBCM_Config`, which defines `FACTSET_USER` and `FACTSET_APIKEY`. That keeps
  keys out of both source control and every individual pipeline notebook. It is *not* a
  substitute for Azure Key Vault — workspace membership is the real access boundary, so
  treat adding someone to the workspace as handing them the live FactSet key.
- **Libraries** belong on a Fabric Environment bound to the notebook, not `%pip`. Inline
  installs are disabled by default in pipeline runs, unsupported in reference runs, and not
  retained between runs.
- **SDK versions** track upstream `FactSet/enterprise-sdk` `main`, *not* the copies
  vendored under `code/python/` here — this mirror lags (SPAREngine is at 2.0.3 locally
  vs. 3.0.0 upstream, PAEngine 2.2.2 vs. 4.0.0). Current as of 2026-08-06:
  `fds.sdk.SPAREngine==3.0.0`, `fds.sdk.PAEngine==4.0.0`,
  `fds.sdk.UniversalScreening==2.0.0`, `fds.sdk.utils==3.0.1`,
  `fds.protobuf.stach.extensions==1.3.3`. All Python SDKs took a coordinated major bump
  on 2026-05-20 that dropped Python ≤3.9 and moved to `urllib3>=2.7.0`; PA Engine took a
  further breaking change on 2026-07-21 (required fields dropped from
  `PADateParameters`). Notebooks assert their SDK major at import so a stale Environment
  fails loudly instead of erroring downstream.
- **Python, not PySpark.** These workloads are megabytes; a Spark cold start costs more
  than the work.
