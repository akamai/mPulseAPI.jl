`filters::Dict`
:    A dict of filters to pass to the mPulse Query API. For example `Dict("page-group" => "foo-bar")`
     will filter results to the `foo-bar` `page-group`.  The resulting filters will be a merge of
     what is passed in and the default values with whatever is passed in taking precedence.

     The default filters are:

         Dict(
             "date-comparator" => "Last24Hours",
         )

     The `date-start` and `date-end` filters accept a `DateTime` object while the `date` filter
     accepts a `Date` object.

     If you'd like to use a `ZonedDateTime`, pass in its `utc_datetime` field:

         filters = Dict(
             "date-comparator" => "Between",
             "date-start"      => ZonedDateTime(2016, 10, 19, 4, 30, TimeZone("America/New_York")).utc_datetime,
             "date-end"        => DateTime(2016, 10, 19, 16, 30)
         )

     To pass multiple values for a single filter, use an array:

         filters = Dict(
             "beacon-type" => ["page view", "xhr", "spa", "spa_hard"],
             "page-group"  => ["product", "search"]
         )
