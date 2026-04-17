xml_str = "<root><floatval>3.14</floatval><intval>42</intval><boolval>true</boolval></root>"

# getXMLNode — string body: exercises the AbstractString parse_string path (L63-64)
node = mPulseAPI.getXMLNode(xml_str, "floatval")
@test !isnothing(node)
@test content(node) == "3.14"

# getXMLNode — unknown body type: exercises the ArgumentError else branch (L70)
@test_throws ArgumentError mPulseAPI.getXMLNode(42, "floatval")
@test_throws ArgumentError mPulseAPI.getXMLNode(3.14, "floatval")

# getNodeContent — Float default: exercises the parse(Float64, ...) branch (L29)
@test mPulseAPI.getNodeContent(xml_str, "floatval", 0.0) ≈ 3.14

# getNodeContent — node not found: exercises the `value = default` else branch (L40)
@test mPulseAPI.getNodeContent(xml_str, "nonexistent", 99.0) ≈ 99.0
@test mPulseAPI.getNodeContent(xml_str, "nonexistent", "fallback") == "fallback"
@test mPulseAPI.getNodeContent(xml_str, "nonexistent", 0) == 0
