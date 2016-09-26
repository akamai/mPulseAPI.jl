`{Dict}` of Custom Metric names mapped to RedShift fieldnames with the following structure:

     Dict(
         <metric name> => Dict(
             "index"        => <index>,                      # Numeric index
             "fieldname"    => "custom_metrics_<index>",     # Field name in dswb tables
             "lastModified" => <lastModifiedDate>,
             "description"  => "<description>",
             "dataType"     => Dict(
                 "decimalPlaces"  => "2",
                 "type"           => "<metric type>",
                 "currencyCode"   => "<ISO 4217 Currency Code if type==Currency>"
             ),
             "colors"       => [<array of color HEX codes>]
         ),
         ...
     )
