* `body::{AbstractString|XMLElement|Dict}` This is an object containing the domain XML returned by `mPulseAPI.getRepositoryDomain`.  It may be:
   * An `AbstractString` containing the domain XML.  This will be parsed.
   * A `LightXML.XMLElement` pointing to the root node of the domain XML.
   * A `Dict` with a `body` element. This is the domain object returned by `mPulseAPI.getRepositoryDomain`.

