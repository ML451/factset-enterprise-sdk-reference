# HBCM notebooks

Heron Bay Capital Management additions to this FactSet SDK reference mirror. Nothing here
is vendor code — everything under `hbcm/` is ours, and nothing under `code/`, `specs/`,
`config/`, or `docs/` is modified, so upstream syncs stay clean.

## `notebooks/`

Fabric **Python** notebook templates (import via *Workspace → Import → Notebook*). They
target the `HBCM - Production` workspace and the `hbcm_datahub` lakehouse.

| Notebook | What it does |
|---|---|
| `spar_composite_returns_template.ipynb` | SPAR Engine returns for the four active GIPS composites vs. their benchmarks, gross/net toggle, multiple SPAR components ("tiles"), as-of most recent quarter end → `factset.spar_composite_returns` |

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
