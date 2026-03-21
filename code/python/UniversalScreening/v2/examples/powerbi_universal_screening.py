"""
Power BI Python Script - FactSet Universal Screening

Run a saved FactSet Universal Screen and return the results as a pandas
DataFrame that Power BI can import as a table.

Prerequisites:
    pip install fds.sdk.utils fds.sdk.UniversalScreening==1.2.0 pandas

Usage in Power BI:
    1. Install the prerequisites in the Python environment Power BI is
       configured to use (File > Options > Python scripting).
    2. Edit the USER CONFIGURATION section below with your credentials
       and screen name.
    3. In Power BI: Get Data > Python script > paste this script > OK.
    4. Power BI will detect the 'screening_results' DataFrame as a table.
"""

import time
import pandas as pd
from fds.sdk.utils.authentication import ConfidentialClient

import fds.sdk.UniversalScreening
from fds.sdk.UniversalScreening.api import screening_operations_api
from fds.sdk.UniversalScreening.models import *

# ============================================================
# USER CONFIGURATION - Edit the values below
# ============================================================

# Authentication method: "oauth" or "basic"
AUTH_METHOD = "basic"

# OAuth 2.0 settings (used when AUTH_METHOD = "oauth")
OAUTH_CONFIG_PATH = "/path/to/app-config.json"

# Basic Auth settings (used when AUTH_METHOD = "basic")
BASIC_USERNAME = "USERNAME-SERIAL"  # e.g. "JOHN_DOE-1234"
BASIC_API_KEY = "API-KEY"

# Screen to run (path to your saved Universal Screen)
SCREEN_NAME = "SAMPLE_SCREENS:KPI_AIR.USWEB"

# Optional: backtest date override (e.g. "20231231") or None for default
BACKTEST_DATE = None

# Optional: global variable overrides (e.g. {"VAR1": "value1"}) or None
GLOBAL_VARIABLES = None

# Polling: how often to check job status, and max wait time
POLL_INTERVAL_SECONDS = 5
MAX_POLL_ATTEMPTS = 120  # 120 * 5s = 10 minutes max

# Pagination: rows per page (min 1000, max 100000)
PAGE_SIZE = 10000

# ============================================================
# END OF USER CONFIGURATION
# ============================================================

# --- Authentication ---
if AUTH_METHOD.lower() == "oauth":
    configuration = fds.sdk.UniversalScreening.Configuration(
        fds_oauth_client=ConfidentialClient(OAUTH_CONFIG_PATH)
    )
elif AUTH_METHOD.lower() == "basic":
    configuration = fds.sdk.UniversalScreening.Configuration(
        username=BASIC_USERNAME,
        password=BASIC_API_KEY,
    )
else:
    raise ValueError(f"AUTH_METHOD must be 'oauth' or 'basic', got '{AUTH_METHOD}'")

# --- Build request ---
calc_params = ScreenCalcParameters(
    data=ScreenCalcParametersData(
        screen_name=SCREEN_NAME,
        **({"backtest_date": BACKTEST_DATE} if BACKTEST_DATE else {}),
        **({"global_variables_map": GLOBAL_VARIABLES} if GLOBAL_VARIABLES else {}),
    )
)

# --- Submit, poll, and fetch results ---
try:
    with fds.sdk.UniversalScreening.ApiClient(configuration) as api_client:
        api = screening_operations_api.ScreeningOperationsApi(api_client)

        # Step 1: Submit the screen calculation
        submit_response = api.submit_calculate(
            screen_calc_parameters=calc_params
        )
        job_id = submit_response.data.id

        # Step 2: Poll until the job completes
        for _attempt in range(MAX_POLL_ATTEMPTS):
            poll_response = api.poll_calculate(job_id)
            status = poll_response.data.status

            if status == "created":
                break
            elif status == "failed":
                raise RuntimeError(
                    f"Screen calculation failed: {poll_response.data.error}"
                )
            elif status == "cancelled":
                raise RuntimeError("Screen calculation was cancelled.")
            elif status in ("queued", "executing"):
                time.sleep(POLL_INTERVAL_SECONDS)
            else:
                raise RuntimeError(f"Unexpected job status: {status}")
        else:
            raise TimeoutError(
                f"Screen calculation did not complete within "
                f"{MAX_POLL_ATTEMPTS * POLL_INTERVAL_SECONDS} seconds."
            )

        # Step 3: Fetch results (with pagination for large screens)
        all_data = {}
        cursor = 0

        while True:
            results_response = api.get_calculate_results(
                job_id,
                pagination_limit=PAGE_SIZE,
                pagination_cursor=cursor,
            )

            page_data = results_response.to_dict().get("data", {})
            if not all_data:
                all_data = page_data
            else:
                for col, values in page_data.items():
                    if col in all_data:
                        all_data[col].extend(values)
                    else:
                        all_data[col] = values

            # Check for more pages
            pagination = getattr(
                getattr(results_response, "meta", None), "pagination", None
            )
            next_cursor = getattr(pagination, "next", None) if pagination else None
            if next_cursor is None:
                break
            cursor = int(next_cursor)

except fds.sdk.UniversalScreening.ApiException as e:
    raise RuntimeError(
        f"FactSet API error: {e.status} - {e.reason}\n{e.body}"
    ) from e

# --- Output: Power BI will auto-detect this DataFrame ---
screening_results = pd.DataFrame(all_data)

# When running outside Power BI (e.g. terminal), print a preview
if __name__ == "__main__":
    print(
        f"Retrieved {len(screening_results)} rows, "
        f"{len(screening_results.columns)} columns"
    )
    print(screening_results.head(10))
