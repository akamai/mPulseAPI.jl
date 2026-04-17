# mPulseAPI.jl — Skills Reference for AI Agents

`mPulseAPI.jl` is a Julia library (v1.3.0) for communicating with the [Akamai mPulse](https://techdocs.akamai.com/mpulse/reference/api) Query, Repository, and Annotations REST APIs.  It is written for Julia ≥ 1.6 and depends on `DataFrames`, `HTTP`, `JSON`, `LightXML`, `TimeZones`, `Dates`, and `Format`.

## Package Layout

| File | Purpose |
|------|---------|
| `src/mPulseAPI.jl` | Module entry point; sets API endpoints, `verbose` flag |
| `src/Token.jl` | Authentication (`getRepositoryToken`) |
| `src/RepositoryAPI.jl` | Generic CRUD helpers for repository objects |
| `src/Domain.jl` | Domain (app) repository calls |
| `src/Tenant.jl` | Tenant repository calls |
| `src/Alert.jl` | Alert repository calls |
| `src/StatisticalModel.jl` | Statistical model repository calls |
| `src/QueryAPI.jl` | All query (analytics) API calls; returns `DataFrame`s |
| `src/BeaconAPI.jl` | Send beacons via `config.json` endpoint |
| `src/cache_utilities.jl` | In-memory object cache (TTL-based) |
| `src/xml_utilities.jl` | XML parsing helpers (`getXMLNode`, `getNodeContent`) |
| `src/Annotation.jl` | Annotations API (`getAnnotation`, `getAnnotations`) |
| `src/exceptions.jl` | Exception type definitions |
| `doc-snippets/*.md` | Shared docstring fragments interpolated via `readdocs()` |

---

## Authentication

### `getRepositoryToken(tenant, apiToken) → String`

Logs in to the mPulse Repository and returns an auth token. Tokens are cached in memory for **5 hours**; subsequent calls with the same tenant return immediately without a network round-trip.

```julia
token = mPulseAPI.getRepositoryToken("MyTenant", "my-api-token")
```

- `token` — used as the `X-Auth-Token` header for all Repository API calls and as the `Authentication` header for all Query API calls.
- Clear a stale token with `mPulseAPI.clearTokenCache("MyTenant")`.

---

## Repository API — Domain (App)

### `getRepositoryDomain(token; domainID, appKey, appName, filters) → Dict | Array{Dict}`

Fetches one or all domain (app) objects. Pass at least one of `domainID`, `appKey`, or `appName` to get a single domain. Pass none to get all domains accessible by the token.

Domains are cached for **1 hour**. Clear with `mPulseAPI.clearDomainCache(; domainID, appKey, appName)`.

**Returned `Dict` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | App name in mPulse |
| `id` | `Int64` | App numeric ID |
| `attributes` | `Dict` | App attributes including `appKey` / `apiKey` |
| `body` | `LightXML.XMLElement` | Parsed XML definition of the app |
| `custom_metrics` | `Dict` | Map of custom metric name → field info (index, fieldname, etc.) |
| `custom_timers` | `Dict` | Map of custom timer name → field info |
| `session_timeout` | `Int64` | Session timeout in minutes |
| `resource_timing` | `Bool` | Whether resource timing is enabled |
| `vertical_market` | `String` | Vertical market category |
| `tenantID` | `Int64` | Parent tenant ID |
| `created` | `DateTime` | Creation timestamp |
| `lastModified` | `DateTime` | Last-modified timestamp |
| `dswb_table_name` | `String` | Beacon table name, e.g. `"beacons_12345"` |

**Common access patterns:**

```julia
domain = mPulseAPI.getRepositoryDomain(token, appName="My App")

domain["attributes"]["appKey"]             # App Key / API Key
domain["custom_metrics"]["Conversion"]["fieldname"]  # DB field for a custom metric
domain["dswb_table_name"]                  # e.g. "beacons_12345"

# Parse XML body
node = mPulseAPI.getXMLNode(domain, "SessionTimeout")
value = mPulseAPI.getNodeContent(domain, "KeepBots", false)
```

---

## Repository API — Tenant

### `getRepositoryTenant(token; tenantID, name, filters) → Dict | Array{Dict}`

Fetches one or all tenants. Cached for 1 hour. Clear with `mPulseAPI.clearTenantCache(; tenantID, name)`.

**Returned `Dict` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Tenant name |
| `id` | `Int64` | Tenant numeric ID |
| `body` | `XMLElement` | Tenant XML definition |
| `dswbUrls` | `Array{String}` | Valid DSWB auth redirect URLs |
| `attributes` | `Dict` | Tenant attributes |
| `parentID` | `Int64` | Parent folder ID |
| `path` | `String` | Folder path |
| `created` / `lastModified` | `DateTime` | Timestamps |

---

## Repository API — Alerts

### `getRepositoryAlert(token; alertID, alertName, domain, filters) → Dict | Array{Dict}`

Fetches one or all alerts. Cached for 1 hour.

### `postRepositoryAlert(token; alertID, alertName, domain, attributes, objectFields, body) → HTTP.Response`

Creates or updates an alert.

### `deleteRepositoryAlert(token; alertID, alertName, domain) → HTTP.Response`

Deletes an alert. Throws `ErrorException` if the server returns non-204.

---

## Repository API — Statistical Models

### `getRepositoryStatModel(token; statModelID, statModelName, filters) → Dict | Array{Dict}`

Fetches one or all statistical model objects. Cached for 1 hour.

### `postRepositoryStatModel(token; statModelID, statModelName, attributes, objectFields, body) → HTTP.Response`

Creates or updates a statistical model. Note: for `statisticalmodel` types, all existing attributes are merged with the new ones before posting.

### `deleteRepositoryStatModel(token; statModelID, statModelName) → HTTP.Response`

Deletes a statistical model. Throws `ErrorException` if the server returns non-204.

---

## Query API

All Query API functions accept `token::AbstractString` and `appKey::AbstractString` as positional arguments and `filters::Dict` as a keyword argument.

### Common `filters` keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `"date-comparator"` | `String` | `"Last24Hours"` | Time range preset |
| `"date-start"` | `DateTime` | — | Start of custom range (use with `"Between"`) |
| `"date-end"` | `DateTime` | — | End of custom range |
| `"date"` | `Date` | — | Single-day filter |
| `"page-group"` | `String\|Array` | — | Filter to page group(s) |
| `"beacon-type"` | `String\|Array` | — | e.g. `["page view", "xhr", "spa"]` |

Pass a `DateTime` directly; the library converts to ISO-8601 with second precision. Pass multiple values as a `Vector`.

```julia
filters = Dict(
    "date-comparator" => "Between",
    "date-start"      => DateTime(2024, 1, 1),
    "date-end"        => DateTime(2024, 1, 31, 23, 59, 59),
    "page-group"      => ["product", "checkout"]
)
```

---

### `getAPIResults(token, appKey, query_type; filters) → Any`

Low-level generic query. Returns a Julia representation of the raw JSON. Prefer the typed wrappers below.

Valid `query_type` values: `"summary"`, `"histogram"`, `"sessions-per-page-load-time"`, `"metric-per-page-load-time"`, `"timers-metrics"`, `"by-minute"`, `"page-groups"`, `"browsers"`, `"ab-tests"`, `"geography"`, `"metrics-by-dimension"`.

---

### `getSummaryTimers(token, appKey; filters) → Dict`

Returns summary statistics for the current time period.

| Key | Type | Description |
|-----|------|-------------|
| `"n"` | `Int` | Beacon count |
| `"median"` | `Int` | Median page load time (ms) |
| `"p95"` | `Int` | 95th percentile (ms) |
| `"p98"` | `Int` | 98th percentile (ms) |
| `"moe"` | `Float` | 95% CI margin of error on the mean (ms) |

---

### `getTimersMetrics(token, appKey; filters) → DataFrame`

Returns a time-series `DataFrame` — one row per time-unit (e.g. 1440 rows for Last24Hours) plus a final summary row.

Always-present columns: `:Beacons`, `:PageLoad`.  Present when available: `:Sessions`, `:BounceRate`, `:DNS`, `:TCP`, `:SSL`, `:FirstByte`, `:DomLoad`, `:DomReady`, `:FirstLastByte`, plus any custom timers and metrics.

---

### `getPageGroupTimers(token, appKey; filters, friendly_names) → DataFrame`

Columns: `:page_group`, `:t_done_median`, `:t_done_moe`, `:t_done_count`, `:t_done_total_pc`.  
Set `friendly_names=true` for human-readable column names.

---

### `getBrowserTimers(token, appKey; filters, friendly_names) → DataFrame`

Columns: `:user_agent`, `:t_done_median`, `:t_done_moe`, `:t_done_count`, `:t_done_total_pc`.

---

### `getABTestTimers(token, appKey; filters, friendly_names) → DataFrame`

Columns: `:test_name`, `:t_done_median`, `:t_done_moe`, `:t_done_count`, `:t_done_total_pc`.

---

### `getGeoTimers(token, appKey; filters, friendly_names) → DataFrame`

Columns: `:country`, `:t_done_median`, `:t_done_count`, `:t_done_total_pc`.

---

### `getMetricsByDimension(token, appKey, dimension; filters) → DataFrame`

Splits all custom metrics by a dimension. Valid `dimension` values: `"page_group"`, `"browser"`, `"country"`, `"bw_block"`, `"ab_test"`.

Columns: `:<dimension>`, then one column per custom metric.

---

### `getHistogram(token, appKey; filters) → Dict`

Returns a histogram of page load time distribution.

| Key | Type | Description |
|-----|------|-------------|
| `"buckets"` | `DataFrame` | Columns: `bucket_start`, `bucket_end`, `element_count` |
| `"median"` | `Int` | Median value |
| `"percentile"` | `Float` | Percentile value |

---

### `getSessionsOverPageLoadTime(token, appKey; filters) → DataFrame`

Columns: `:t_done` (ms), `:Sessions` (count).

---

### `getMetricOverPageLoadTime(token, appKey; filters, metric) → DataFrame`

Columns: `:t_done` (ms), `:<metric>`. Default metric is `"BounceRate"`.

---

### `getTimerByMinute(token, appKey; filters, timer) → DataFrame`

Returns minute-by-minute timeseries. Valid `timer` values: `"PageLoad"` (default), `"DNS"`, `"TCP"`, `"SSL"`, `"FirstByte"`, `"DomLoad"`, `"DomReady"`, `"FirstLastByte"`, or any custom timer name.

Columns: `:timestamp` (ms since epoch), `:<TimerName>` (ms), `:moe` (ms).

---

### `mergeMetrics(df1, df2...; keyField=:t_done, joinType=:outer) → DataFrame`

Joins multiple `DataFrame`s from `getMetricOverPageLoadTime` / `getSessionsOverPageLoadTime` on a shared key column. All input `DataFrame`s must contain the `keyField` column.

```julia
sessions   = mPulseAPI.getSessionsOverPageLoadTime(token, appKey)
bouncerate = mPulseAPI.getMetricOverPageLoadTime(token, appKey)
conversion = mPulseAPI.getMetricOverPageLoadTime(token, appKey, metric="Conversion")

merged = mPulseAPI.mergeMetrics(sessions, bouncerate, conversion)
```

---

## Annotations API

The Annotations API surfaces the real-time alerting annotation history for a domain.  Annotations are written automatically by the mPulse alerting system when an anomaly is detected or cleared, and can be used to reconstruct alert history without re-running detection models locally.

The annotations endpoint is `<APIEndpoint>/mpulse/api/annotations/v1` and is set automatically when `setEndpoints` is called.

### `getAnnotation(token, annotationID) → Dict{String, Any}`

Fetches a single annotation by numeric ID.

```julia
annotation = mPulseAPI.getAnnotation(token, 42)
```

**Arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| `token` | `AbstractString` | Auth token from `getRepositoryToken` |
| `annotationID` | `Int64` | Positive integer annotation ID |

**Returned `Dict` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `"id"` | `Int` | Unique annotation ID |
| `"title"` | `String` | Short description (typically the alert name) |
| `"start"` | `Int` | Annotation start time (epoch milliseconds) |
| `"end"` | `Int` | Annotation end time (epoch milliseconds) |
| `"domainID"` | `Int` | Domain this annotation belongs to |

Additional fields may be present depending on mPulse API version.

**Throws:** `ArgumentError` (empty token or non-positive ID), `mPulseAPIAuthException` (HTTP 401), `mPulseAPIBugException` (HTTP 500), `mPulseAPIException` (other error).

---

### `getAnnotations(token; domainID, dateStart, dateEnd) → Vector`

Fetches all annotations matching the given filters.

```julia
using Dates

# All annotations for a domain in a time range
annotations = mPulseAPI.getAnnotations(token,
    domainID  = 12345,
    dateStart = DateTime(2024, 1, 1),
    dateEnd   = DateTime(2024, 1, 31, 23, 59, 59)
)

# All annotations for the entire tenant (no filters)
annotations = mPulseAPI.getAnnotations(token)
```

**Keyword arguments:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `domainID` | `Union{Int64, Nothing}` | `nothing` | Filter to a specific domain; `nothing` returns all domains |
| `dateStart` | `Union{DateTime, ZonedDateTime, Nothing}` | `nothing` | Start of time range (inclusive); converted to epoch ms |
| `dateEnd` | `Union{DateTime, ZonedDateTime, Nothing}` | `nothing` | End of time range (inclusive); converted to epoch ms |

**Returns:** `Vector` of annotation `Dict`s (same shape as `getAnnotation`). The API may return either a bare JSON array or `{"annotations": [...]}` — both are normalised to a `Vector` by the library.

**Throws:** `ArgumentError` (empty token), `mPulseAPIAuthException`, `mPulseAPIBugException`, `mPulseAPIException`, `mPulseAPIResultFormatException` (unexpected response format).

---

## Beacon API

### `getBeaconConfig(appKey, appDomain) → Dict`

Fetches the `config.json` for an mPulse app. Result is cached according to the `Cache-Control: max-age` response header.

### `sendBeacon(config, params) → Bool`

Sends a beacon using the config returned by `getBeaconConfig`. Returns `true` on HTTP 204 (success).

**Supported `params` keys:** `"SessionID"`, `"SessionStart"`, `"SessionLength"`, `"PageGroup"`, `"Url"`, `"tDone"`, `"tStart"`, plus any custom metric/dimension/timer names defined in the app config.

```julia
config = mPulseAPI.getBeaconConfig(appKey, "www.example.com")
mPulseAPI.sendBeacon(config, Dict("tDone" => 1234, "PageGroup" => "home"))
```

---

## XML Utilities

### `getXMLNode(body, nodeName) → XMLElement | nothing`

Searches for a named child element in an XML body. `body` can be an XML `String`, a `LightXML.XMLElement`, or a repository object `Dict` (uses `body["body"]`).

### `getNodeContent(body, nodeName, default) → Any`

Returns the text content of a named XML node, auto-coerced to `Int`, `Float64`, `Bool`, or `String`. Returns `default` if the node does not exist.

```julia
timeout = mPulseAPI.getNodeContent(domain, "SessionTimeout", 30)   # → Int
keepbots = mPulseAPI.getNodeContent(domain, "KeepBots", false)      # → Bool
```

---

## Cache Management

Each object type has a 1-hour TTL by default (tokens: 5 hours).

| Function | Clears |
|----------|--------|
| `mPulseAPI.clearDomainCache(; domainID, appKey, appName)` | Domain cache |
| `mPulseAPI.clearTenantCache(; tenantID, name)` | Tenant cache |
| `mPulseAPI.clearTokenCache(tenant)` | Token cache (resets timestamp, preserves credentials) |
| `mPulseAPI.clearAlertCache(; alertID, alertName, domain)` | Alert cache |
| `mPulseAPI.clearStatModelCache(; statModelID, statModelName)` | Statistical model cache |

---

## Exception Types

All exceptions are subtypes of `Exception` and are exported.

| Type | When thrown |
|------|------------|
| `mPulseAPIException` | Non-2xx HTTP response from the API |
| `mPulseAPIAuthException` | Invalid or expired auth token (HTTP 401) |
| `mPulseAPIRequestException` | Invalid request parameter; fields: `msg`, `code`, `parameter`, `value`, `response` |
| `mPulseAPIResultFormatException` | Unexpected response format; fields: `msg`, `data` |
| `mPulseAPIBugException` | Internal server error (HTTP 500) |

---

## Configuration

### `mPulseAPI.setEndpoints(APIEndpoint)` 

Override the default endpoint `https://mpulse.soasta.com/concerto`. Useful for staging or alternate environments.

```julia
mPulseAPI.setEndpoints("https://mpulse-alt.soasta.com/concerto")
```

### `mPulseAPI.setVerbose(true)`

Prints all URLs, headers, and POST bodies to stdout before each API call. Useful for debugging.

---

## Typical Usage Pattern

```julia
using mPulseAPI

# 1. Authenticate
token = mPulseAPI.getRepositoryToken("MyTenant", "my-api-token")

# 2. Look up the domain to get the App Key
domain = mPulseAPI.getRepositoryDomain(token, appName="My App")
appKey = domain["attributes"]["appKey"]

# 3. Query analytics
summary = mPulseAPI.getSummaryTimers(token, appKey)
println("Median page load: $(summary["median"]) ms over $(summary["n"]) beacons")

# 4. Time-series data for the last 7 days
filters = Dict("date-comparator" => "Last7Days")
ts = mPulseAPI.getTimerByMinute(token, appKey, filters=filters, timer="PageLoad")

# 5. Custom time range
filters = Dict(
    "date-comparator" => "Between",
    "date-start"      => DateTime(2024, 6, 1),
    "date-end"        => DateTime(2024, 6, 30, 23, 59, 59)
)
metrics = mPulseAPI.getTimersMetrics(token, appKey, filters=filters)
```

---

## Testing Notes (for contributors)

- Tests live in `test/`. The main entry point is `test/runtests.jl`.
- **Live integration tests** require `mPulseAPIToken` and `mPulseAPITenant` environment variables.
- **Mock tests** (in `test/mock-tests.jl`) use `Test.GenericString` dispatch overloads for `HTTP.get` and `HTTP.post` to intercept calls without a live server. The mock testset **must run last** in `runtests.jl` because the HTTP overloads persist for the remainder of the test session.
- Use `Test.GenericString(token_value)` to select a mock scenario by token string value.
- **Annotation tests** live in `test/annotation-tests.jl` and are included near the end of `runtests.jl` (before the mock testset). They cover `getAnnotation`, `getAnnotations`, and all exception/edge-case paths.
