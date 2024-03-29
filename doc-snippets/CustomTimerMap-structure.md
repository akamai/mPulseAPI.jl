`{Dict}` of Custom Timer names mapped to database fieldnames with the following structure:

```julia
Dict(
    <timer name> => Dict(
        "index"         => <index>,                      # Numeric index
        "fieldname"     => "customtimer<index>",         # Field name in dswb tables
        "mpulseapiname" => "CustomTimer<index>",
        "lastModified"  => <lastModifiedDate>,
        "description"   => "<description>",
        "colors"        => Array(
            Dict(
                "timingType"  => "<seconds | milliseconds>",
                "timingStart" => "<start timer value for this colour range>",
                "timingEnd"   => "<end timer value for this colour range>",
                "colorStart"  => "<start of this color range>",
                "endStart"    => "<end of this color range>"
            ),
            ...
        )
    ),
    ...
)
```
