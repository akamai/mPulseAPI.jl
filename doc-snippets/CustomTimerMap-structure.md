`{Dict}` of Custom Timer names mapped to RedShift fieldnames with the following structure:

     Dict(
         <timer name> => Dict(
             "index"         => <index>,                      # Numeric index
             "fieldname"     => "timers_custom<index>",       # Field name in dswb tables
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
