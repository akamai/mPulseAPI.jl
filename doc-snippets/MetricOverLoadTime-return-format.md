`{DataFrame}` A julia `DataFrame` mapping the {1} to a load time bucket:

```julia
julia> mPulseAPI.get{1}OverPageLoadTime(token, appID)
60x2 DataFrames.DataFrame
| Row | t_done | {2:10s} |
|-----|--------|------------|
| 1   | 8      | 50.0       |
| 2   | 9      | 100.0      |
| 3   | 10     | 100.0      |
| 4   | 12     | 100.0      |
| 5   | 16     | 100.0      |
| 6   | 18     | 100.0      |
| 7   | 22     | 100.0      |
| 8   | 26     | 100.0      |
```
