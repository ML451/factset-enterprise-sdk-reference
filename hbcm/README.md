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
- **Python, not PySpark.** These workloads are megabytes; a Spark cold start costs more
  than the work.
