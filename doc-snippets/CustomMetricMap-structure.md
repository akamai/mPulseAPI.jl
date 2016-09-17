`{Dict}` of Custom Metric names mapped to RedShift fieldnames with the following structure:

     Dict(
         <metric name> => Dict(
             "index"        => <index>,                          # Numeric index
             "fieldname"    => "custom_metrics_<index>",     # Field name in dswb tables
             "lastModified" => <lastModifiedDate>,
             "description"  => "<description>",
             "dataType"     => Dict(
                 "decimalPlaces"  => "2",
                 "type"           => "<metric type>",
                 "currencySymbol" => "<symbol if this is a currency type>"
             ),
             "colors"       => [<array of color HEX codes>]
         ),
         ...
     )
