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
