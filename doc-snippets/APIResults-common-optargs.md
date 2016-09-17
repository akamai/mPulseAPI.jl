`filters::Dict`
:    A dict of filters to pass to the mPulse Query API. For example `Dict("page-group" => "foo-bar")`
     will filter results to the `foo-bar` `page-group`.  The resulting filters will be a merge of
     what is passed in and the default values with whatever is passed in taking precedence.

     The default filters are:

         Dict(
             "date-comparator" => "Last24Hours",
             "format" => "json",
             "series-format" => "json"
         )
