# Argument validation — no live endpoint needed
@test_throws ArgumentError getAnnotations("")
@test_throws ArgumentError getAnnotation("", Int64(1))

# Bad token triggers 401 → mPulseAPIAuthException
@test_throws mPulseAPIAuthException getAnnotations("bad-token")
@test_throws mPulseAPIAuthException getAnnotation("bad-token", Int64(1))

token  = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)

@test_throws ArgumentError getAnnotation(token, Int64(0))
@test_throws ArgumentError getAnnotation(token, Int64(-1))

# Fetch all annotations for the tenant (domainID is optional)
annotations = getAnnotations(token)
@test isa(annotations, Vector)

# Fetch with date range
annotations_with_dates = getAnnotations(token,
    dateStart = now() - Dates.Day(30),
    dateEnd   = now()
)
@test isa(annotations_with_dates, Vector)

mPulseAPIAnnotationDomainID = something(tryparse(Int64, get(ENV, "mPulseAPIAnnotationDomainID", "0")), Int64(0))

if mPulseAPIAnnotationDomainID > 0
    domain_annotations = getAnnotations(token, domainID=mPulseAPIAnnotationDomainID)
    @test isa(domain_annotations, Vector)
end

if !isempty(annotations_with_dates)
    ann = annotations_with_dates[1]
    @test haskey(ann, "id")
    @test haskey(ann, "start")

    annotation = getAnnotation(token, ann["id"])
    @test annotation["id"] == ann["id"]
end
