`{DataFrame}` A julia `DataFrame` mapping the {1} to a load time bucket:

```julia
julia> mPulseAPI.get{1}OverPageLoadTime(token, appID)
60x2 DataFrames.DataFrame
| Row | t_done | {2:10s} |
|-----|--------|------------|
| 1   | 210    | {3:5s}      |
| 2   | 300    | {4:5s}      |
| 3   | 400    | {3:5s}      |
| 4   | 500    | {5:5s}      |
| 5   | 550    | {6:5s}      |
| 6   | 600    | {7:5s}      |
| 7   | 700    | {5:5s}      |
| 8   | 800    | {8:5s}      |
| 9   | 900    | {9:5s}      |
| 10  | 1050   | {10:5s}      |
```
