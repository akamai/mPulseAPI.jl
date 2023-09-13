###############################################################################################
#
#  Extract raw Markdown from source files and turn them into docs
#
#  - Use `names(module)` to get a list of exported symbols from the module
#  - Use Docs.meta to get all documented symbols along with path to the sourcefile
#  - Use `grep` to get line number in file
#  - Use readlines to read in the source file and pull out docs & end line number
#    - because julia compiles docs to Markdown objects, and discards the raw MD
#  - Re-execute all docstrings because they may include external files
#  - Write .md files and a TOC, add links back to repo with start/end lines for each object
#  - Create mkdocs.yml
#  - Run `mkdocs` to build html docs
#  - Cleanup (optional)
#
#
#              -- Because julia's own documentation libraries cannot handle all of markdown
#
###############################################################################################

using ArgParse
import Formatting, Pkg, YAML, InteractiveUtils
import InteractiveUtils.subtypes

s = ArgParseSettings()
@add_arg_table s begin
    "--config-file", "-f"
        help = "Configuration yaml file"
        default = joinpath(@__DIR__, "mkdocs.yml")
        metavar = "<mkdocs.yml>"
    "--delete"
        help = "Delete generated md files"
        action = :store_true
    "--add"
        help = "Add docs to git"
        action = :store_true
end

run_config = parse_args(s)

struct Macro end

struct Page
    mod::AbstractString
    name::AbstractString
    title::AbstractString
end


# TODO: Handle Base.Docs.Binding
const declarator = Dict(
    Function => "function +(\\w+\\.)?{1}[{{(]",
    DataType => "(abstract type|(mutable +)?struct) +{1}(\\b|\$)",
    Module => "(?:module +)?{1}\$",
    Base.Docs.Binding => "!@#%|^(?:global +|const +)*?{1} *=",
    Macro => "macro +{1}\\b"
)
const supported_types = collect(keys(declarator))

function printwarn(xs...; color=:light_red)
    print("WARN    - ")
    Base.printstyled(xs..., "\n"; color=color)
end

# Now get all the symbols and mark the exported ones
function symbol2dict(file_deets::Dict, k, k_doc)
    name       = replace(string(k), r".*\.:?" => "")

    modl       = file_deets[:mod]
    exported   = haskey(file_deets[:exported], replace(string(k), Regex("^$modl\\.") => ""))

    retvals = Dict[]

    if startswith(name, "@")
        name = name[2:end]
        typ  = Macro
    else
        typ  = typeof(k)
        if typ == Base.Docs.Binding
            altobj = Docs.resolve(k)
            while isa(altobj, UnionAll)
                altobj = altobj.body
            end
            typ = typeof(altobj)
        end

        typidx = findfirst(x -> typ <: x, supported_types)
        if typidx != nothing
            typ = supported_types[typidx]
        else
            typ = typeof(k)
        end
    end

    if k_doc != nothing
        k_doc = collect(values(k_doc.docs))
    else
        try
            k_doc = Docs.doc(k)
        catch ex
            println("ERROR with $k")
            rethrow()
        end

        if k_doc == nothing || !isdefined(k_doc, :meta) || !isdefined(k_doc, :content)
            return retvals
        end

        if !isempty(k_doc.meta[:results])
            k_doc = k_doc.meta[:results]
        elseif typ == Base.Docs.Binding
            k_doc = [(
                data = Dict(:module => modl, :path => ""),
                text = "",
                binding = k
            )]
            local cm = `grep -rEl ^$(Formatting.format(declarator[Base.Docs.Binding], name)) $(dirname(pathof(modl)))`

            possible_path = filter(x -> !occursin(".swp", x), readlines(cm))
            if !isempty(length(possible_path))
                k_doc[1].data[:path] = possible_path[1]
            end
        else
            if string(modl) != string(name)
                printwarn("$modl.$(typ==Macro ? "@" : "")$name has no docs")
            end
            return retvals
        end
    end

    # If this is a MultiDoc, but at least one of the docs really is for this module, then limit to that doc
    if length(k_doc) > 1 && any(r -> r.data[:module] == modl, k_doc)
        k_doc = filter(r -> r.data[:module] == modl, k_doc)
    end

    docmodl = modl
    # If this symbol is from a completely different module, then change the value of modl
    if k_doc[1].data[:module] != modl && !startswith(string(k_doc[1].data[:module]), string(modl, "."))
        modl = k_doc[1].data[:module]
    end

    if modl ∈ [Base, Core]
        # If the only docs available are from Base or Core, then we do not need them
        return retvals
    end

    file  = get(k_doc[1].data, :path, "")

    if file == "" || !isfile(file)
        printwarn("Cannot find source file ($file) for $modl.$name")
        return retvals
    end

    # If the actual module of this function is not our module, it means we added a method to
    # a function from another module; check if it is exported
    exported |= (Symbol(name) ∈ names(modl))

    # If the symbol exists in `Main` then it was exported into Main by something
    exported |= isdefined(Main, Symbol(name))

    # Switch to the environment identified by the module so that imports work
    if Pkg.project().name != string(modl)
        pkg_info = Pkg.dependencies()[Pkg.project().dependencies[string(modl)]]
        Pkg.activate(pkg_info.source)
    end

    deets = get_deets(file, file_deets)
    lines = deets[:lines]

    if !haskey(declarator, typ)
        printwarn("Unknown identifier type $(typ) ($(typeof(typ))) for $(modl).$(name)")
    elseif typ == Function
        local fn = getfield(docmodl, Symbol(name))

        if string(fn) != name
            # This is an alias, so we should use its own documentation
            line = findlast(contains(Regex("^$(Formatting.format(declarator[Base.Docs.Binding], name))")), lines)
            push!(retvals, Dict(
                    :module   => string(modl),
                    :name     => name,
                    :basename => name,
                    :type     => typ,
                    :exported => exported,
                    :file     => basename(file),
                    :repo_url => file_deets[:remote_url],
                    :path     => deets[:remote_path],
                    :branch   => deets[:repo_branch],
                    :line     => line,
                    :endline  => line,
                    :doc      => k_doc[1].text[1]
                )
            )
        else
            local mets = unique(m -> (m.file, m.line), methods(fn, [docmodl, modl]).ms)

            for met in mets
                retval = Dict(
                        :module   => string(met.module),
                        :basename => name,
                        :type     => typ,
                        :exported => exported,
                        :repo_url => file_deets[:remote_url],
                    )

                if Pkg.project().name != string(met.module)
                    pkg_info = Pkg.dependencies()[Pkg.project().dependencies[string(met.module)]]
                    Pkg.activate(pkg_info.source)
                end

                # It's possible that the method is extended and exported in the current module, but only documented in the base module
                # So we need to fudge around a bit to get the method signature from one file but docs from the other
                if string(met.file) != file
                    docdeets = get_deets(string(met.file), file_deets)
                    doclines = docdeets[:lines]
                    retval[:file] = basename(string(met.file))
                else
                    docdeets = deets
                    doclines = lines
                    retval[:file] = basename(file)
                end

                retval[:path]   = docdeets[:remote_path]
                retval[:branch] = docdeets[:repo_branch]

                line = met.line

                if startswith(doclines[line], "function $name")
                    endline = findnext(==("end"), doclines, line)
                else
                    # Format: `(?:Module.)fn_name(params) = statements`
                    re = Regex("^\\s*(\\w+\\.)*$name *\\(|^\\s*(\\w+\\.)*:\\($name\\) *\\(")
                    possible_line = findprev(l -> occursin(re, l), doclines, line)
                    if !isnothing(possible_line)
                        line = possible_line
                        endline = something(findnext(l -> occursin(r"^(\w|$)", l), doclines, line+1), line+1)-1
                    else
                        endline = line
                    end
                end

                if endline == nothing
                    printwarn("Could not find end of function $(modl).$(name), make sure there are no spaces at the end of line.")
                end

                # Don't add multiple dispatches of the same method multiple times
                if any(r -> r[:file] == retval[:file] && r[:line] == line && r[:endline] == endline, retvals)
                    continue
                end

                if modl == met.module
                    api_doc = get_api_doc(doclines, line, retval[:file], modl, name, typ)
                else
                    printwarn("$(docmodl).$(name) does not have its own docs, borrowing from base method $(modl).$(name)."; color=:light_yellow)
                    api_doc = k_doc[1].text[1]
                end

                retval[:line]    = line
                retval[:endline] = endline
                retval[:doc]     = api_doc

                # Don't add multiple dispatches of methods with the same documentation multiple times
                matching_retval = findfirst(r -> r[:doc] == api_doc, retvals)
                if !isnothing(matching_retval)
                    # If we do have multiple dispatches with the same docs,
                    # then make sure the function sig used in the docs is generic
                    retvals[matching_retval][:name] = string(met.name)
                else
                    # If this method extends a function from a different module, then mention that here.
                    if isa(k, Base.Docs.Binding) && k.mod != modl
                        retval[:extends] = "$(k.mod).$(k.var)"
                        retval[:exported] |= (k.var ∈ names(k.mod))
                    end

                    sig = string(met.name)
                    met_sig = met.sig
                    while isa(met_sig, UnionAll)
                        met_sig = met_sig.body
                    end
                    if length(met_sig.parameters) > 1
                        sig *= "(" * join(["::$t" for t in met_sig.parameters[2:end]], ", ") * ")"
                    end

                    retval[:name] = sig

                    push!(retvals, retval)
                end
            end
        end

        # If we had more than one method with at least one documented, then ignore any that had empty docs as they are probably covered by the function docs
        if any(r -> !isempty(r[:doc]), retvals)
            filter!(r -> r[:doc] != "", retvals)
        end

        # If we only had one method, then use the function name rather than the method signature
        if length(retvals) == 1
            retvals[1][:sig]  = retvals[1][:name]
            retvals[1][:name] = retvals[1][:basename]
        end
    else
        line = findlast(contains(Regex("^\\s*$(Formatting.format(declarator[typ], replace(name, r"([{}])" => s"\\\1")))")), lines)

        # We couldn't find the exact type, but it's possible this was an alias of a type, so is defined as a `const`
        if line == nothing && typeof(k) == Base.Docs.Binding
            line = findlast(contains(Regex("^$(Formatting.format(declarator[Base.Docs.Binding], replace(name, r"([{}])" => s"\\\1")))")), lines)
        end

        if line == nothing
            println(Regex("^\\s*$(Formatting.format(declarator[typ], replace(name, r"([{}])" => s"\\\1")))"))
            printwarn("$typ $name not found in $file")
            return retvals
        end

        if typ ∈ [Module, Base.Docs.Binding]
            endline = line
        else
            endline = something(findnext(==("end"), lines, line), 0)
        end

        api_doc = get_api_doc(lines, line, file, modl, name, typ)

        # No docs, but check if this is a Docs.Binding, then provide summary information.
        if isempty(api_doc) && typ == Base.Docs.Binding
            api_doc = generate_autodoc(k)
        end

        doc_has_exports = (typ == Module && occursin(r"^### Exports:$"m, api_doc))

        stype = Any
        ref   = nothing
        if typ == DataType
            ref   = getfield(modl, Symbol(replace(name, r"{.+}" => "")))
            stype = supertype(ref)
        end

        push!(retvals, Dict(
                :module   => string(modl),              # Containing Module name
                :name     => name,                      # Object name
                :type     => typ,                       # Object type
                :stype    => stype,                     # Object super type if object is a DataType
                :ref      => ref,                       # Reference to actual object if object is a DataType
                :exported => exported,                  # Is object exported or not
                :file     => basename(file),            # Source file where object is defined
                :repo_url => file_deets[:remote_url],   # Remote git repository URL where file is stored
                :path     => deets[:remote_path],       # Path on remote git repository where file is stored
                :branch   => deets[:repo_branch],       # Branch on remote git repository where current version of the file exists
                :line     => line,                      # Line number in file where object definition starts
                :endline  => endline,                   # Line number in file where object definition ends
                :doc      => api_doc,                   # Documentation string for object
                :doc_exp  => doc_has_exports            # Does the documentation already have exports included. If not, they may be added automatically
            )
        )
    end

    return retvals
end


function get_deets(file, file_deets)
    if haskey(file_deets, file)
        return file_deets[file]
    end

    deets = Dict()

    cd(dirname(file)) do
        local repo_branch_lines = nothing
        try
            repo_branch_lines = filter(l -> startswith(l, "* "), readlines(`git branch`))
        catch ex
            printwarn("git error for $file")
            rethrow()
        end

        if length(repo_branch_lines) > 0
            deets[:repo_branch] = replace(repo_branch_lines[1], r"^\* (.*)" => s"\1")
        end

        deets[:remote_path] = dirname(chomp(read(`git ls-files --full-name $(basename(file))`, String)))

        if file_deets[:remote_url] == ""
            remote_url = chomp(read(`git ls-remote --get-url`, String))
            remote_url = replace(remote_url, r"^git@([^:]+):(.+)\.git" => s"https://\1/\2")
            file_deets[:remote_url] = remote_url
        end
    end

    lines = open(readlines, file)
    deets[:lines] = lines

    # In order to correctly resolve exported variables used in module documentation, we need to import anything that each file imports
    imports = findall(line -> occursin(r"^\s*(?:@reexport\s+)?(import|using)\s", line) && !occursin(r"\s*using ((Base\.)?Dates|Logging|Test)$", line), lines)
    if length(imports) > 0
        for line in lines[imports]
            try
                eval(Meta.parse(line))
            catch ex
                error("""
                    $file: $ex

                    Error executing imports at.

                        $line
                """)
            end
        end
    end

    file_deets[file] = deets

    return deets
end

function generate_autodoc(k::Base.Docs.Binding)
    println("INFO    - Generating autodocs for $(k.mod).$(k.var)")
    api_doc = "```julia\n"
    if isconst(k.mod, k.var)
        api_doc *= "const "
    end
    api_doc *= string(k.var)

    altobj = Docs.resolve(k)
    while isa(altobj, UnionAll)
        altobj = altobj.body
    end

    if isa(altobj, Vector) || isa(altobj, Set)
        api_doc *= " = $(eltype(altobj))[\n"
        if isbitstype(eltype(altobj))
            local x = collect(altobj)
            local n = clamp(ceil(Int, sqrt(length(x))), 4, 20)
            api_doc *= join([ "    " * join(x[i+1:min(end, i+n)], ", ") for i in 0:n:length(x)-1 ], ",\n")
        else
            api_doc *= join(map(x -> "    " * repr(x), collect(altobj)), ",\n")
        end
        api_doc *= "\n]"
    elseif isa(altobj, Dict)
        api_doc *= " = Dict(\n"
        local kvpairs = collect(altobj)
        local maxklength = maximum(length.(string.(getproperty.(kvpairs, :first))))
        api_doc *= join(map(kv -> "    $(kv[1])$(" "^(maxklength-length(string(kv[1])))) => " * repr(kv[2]), kvpairs), ",\n")
        api_doc *= "\n)"
    elseif length(string(altobj)) < 50
        api_doc *= " = " * repr(altobj)
    else
        api_doc *= string("::", typeof(altobj))
    end
    api_doc *= "\n```\n"

    return api_doc
end

function get_api_doc(lines, line, file, modl, name, typ)
    api_doc = ""

    prev_end      = something(findprev(==("end"), lines, line), 0)

    api_doc_end   = something(findprev(==("\"\"\""), lines, line), 0)
    api_doc_start = something(findprev(==("\"\"\""), lines, api_doc_end-1), 0)

    # If the docs are too far away and non-empty stuff in between
    if line - api_doc_end > 1 && any(x -> !isempty(x), lines[api_doc_end+1:line-1])
        return api_doc
    end

    if api_doc_end > prev_end && api_doc_end - api_doc_start > 0
        api_doc_lines = join(map(x -> endswith(x, "\n") ? x : "$x\n", lines[api_doc_start:api_doc_end]), "")
        try
            # Evaluate expressions in docs
            api_doc = eval(Meta.parse(api_doc_lines))
        catch ex
            if isa(ex, UndefVarError)
                error("""
                    $modl.$name ($typ):
                        Documentation references a foreign variable $(ex.var)
                        Perhaps a \$ wasn't correctly escaped with a \\ in the docs

                        $file:$api_doc_start-$api_doc_end
                    """)
            else
                println(api_doc_lines)
                println(modl, ".", name, " (", typ, ")")
                println(api_doc_start, " => ", api_doc_end , " => ", line)
                rethrow()
            end
        end
    end

    # Julia repl docs use 4 spaces to mark code blocks, while actual markdown uses 4 spaces followed by * to show nested bullet lists
    # We might reference `/static/docs/` when pointing to HTML so that `?function` works, but that needs to be rewritten for markdown
    api_doc = replace(replace(replace(api_doc, r"^   \*"m => "    *"), r"/static/docs/" => "/"), r"/docs/src/" => "/")

    return api_doc
end

function getSymbols(modl::Module; order=[Module, DataType, Macro, Function, Base.Docs.Binding])
    proj_path = Pkg.project().path

    deets = Dict{Any, Any}(
        :mod        => modl,
        :remote_url => "",
        :exported   => Dict( map( n -> (string(n) => getfield(modl, n)), filter( n -> isdefined(modl, n), names(modl) ) ) )
    )

    docmeta = Docs.meta(modl)

    if length(docmeta) > 0
        symbols = mapfoldl(
                        k -> symbol2dict(deets, k, get(docmeta, k, nothing)),
                        ∪,
                        filter(k -> !isa(k, IdDict), collect( keys(docmeta) ) ) ∪
                            map(
                                k -> Docs.Binding(modl, k),
                                filter(k -> isdefined(modl, k), names(modl)) ∪
                                filter(
                                    k -> isdefined(modl, k) &&
                                         isconst(modl, k) &&
                                         (typeof(getfield(modl, k)) <: Number || typeof(getfield(modl, k)) <: AbstractString),
                                    names(modl, all=true, imported=false)
                                )
                            )
                    )
    else
        symbols = []
    end

    expo_order = Dict(true => "1", false => "2")
    type_order = Dict(zip(order, 1:length(order)))

    sort!(symbols, by = x -> Formatting.format("{3}.{1}.{2}.{4:04d}.{5}", expo_order[x[:exported]], type_order[x[:type]], x[:file], x[:line], x[:name]))

    if Pkg.project().path != proj_path
        Pkg.activate(dirname(proj_path))
    end
    return symbols
end

const labels = Pair[Module => "", DataType => "Type", Macro => "Macro", Function => "Function", Base.Docs.Binding => "Constant"]
const exps   = Pair[true => "Exported", false => "Qualified"]

function getPages(ypages)
    local pages = Page[]

    for p in ypages
        local title, value, mod, name

        (title, value) = first(p)

        if isa(value, AbstractArray)
            append!(pages, getPages(value))
        else
            # Prebuilt pages only need references to be updated
            if !occursin("/", value)
                push!(pages, Page(".", value, title))
            else
                (mod, name) = String.(split(value, "/", limit=2))
                name = replace(name, r"\.md" => "")

                push!(pages, Page(mod, name, title))
            end
        end
    end

    return unique(p -> (p.mod, p.name), pages)
end

function fully_qualified_object_description(s::Dict; includepath::Bool=true)
    typeprefix = s[:type] == Base.Docs.Binding ? "" : string(s[:type], "-")
    return (includepath ? joinpath(
            s[:module], s[:file] == s[:module] * ".jl" ? "index.md" : replace(s[:file], r"\.jl$" => ".md")
        ) : "") * lowercase(string(
            "#", typeprefix, replace(replace(s[:name], r"[^\w ]" => ""), " " => "-")
        ))
end

function replace_refs(m, mod=""; addprepath::Bool=true, undocumentedwarning::Bool=true, meta::Dict=Dict())
    ref = match(r"^\[(`?((?:\w+\.)+)?([\w!-]+)`?)\]", m)

    if ref == nothing
        return m
    end

    txt = string(ref.captures[1])

    if ref.captures[2] != nothing
        mod = string(ref.captures[2])
    elseif mod != "" && !endswith(mod, ".")
        mod *= "."
    end

    ref_obj = string(ref.captures[3])

    prepath = addprepath ? ".." : ""

    if haskey(refids, string(mod, ref_obj)) # Module.symbol
        return "[$txt]($(joinpath(prepath, refids[string(mod, ref_obj)]))){: .x-ref}"
    elseif haskey(refids, ref_obj) && ref.captures[2] == nothing  # symbol
        return "[$txt]($(joinpath(prepath, refids[ref_obj]))){: .x-ref}"
    else
        if undocumentedwarning
            println(stderr, "WARNING: Found reference to undocumented identifier `$(ref_obj)'", isempty(mod) ? "" : " in $(mod)", haskey(meta, :file) ? " ($(meta[:name]))" : "", " >>> ", m)
        end
        return txt
    end
end

function processModulePage(page::Page, mdfile_path::AbstractString)
    mod_page_count  = length( filter(p -> p.mod == page.mod, PAGES) )

    if !isdir(dirname(mdfile_path))
        mkdir(dirname(mdfile_path))
    end
    open(mdfile_path * ".md", "w") do md
        if page.name == "index"
            title_text = "module " * page.mod
        else
            title_text = page.mod * ": " * page.title
        end

        println(md, """
            # $(title_text)

            """
        )

        # Get a list of documented symbols for this file
        local file_symbs = unique(
                                sym -> (sym[:file], sym[:line], sym[:endline]),
                                filter(
                                    sym -> sym[:module] == page.mod
                                    && (
                                        (page.name == "index" && sym[:file] == page.mod * ".jl")
                                        ||
                                        (page.name == ".")
                                        ||
                                        (sym[:file] == page.name * ".jl")
                                    ),
                                    symbols
                                 )
                             )


        # Write an index of all documented symbols in this file
        if page.name != "index" ||    # Not an index
          (                           # Or index with just one file, or index with internal symbols and does not have its own API Reference
              (mod_page_count == 1 || length(file_symbs) > 1) &&
              !any(s -> s[:type] == Module && s[:doc_exp], file_symbs)
          )
            # Use HTML here because markdown doesn't support inserting classes into UL and LI elements
            println(md, """<ul class="symbols">""")
            for s in Base.sort(filter(s -> s[:type] != Module, file_symbs), by = s->(!s[:exported], s[:name]))
                Formatting.printfmtln(md, """<li class="{3:s}" title="{3:s}"><a href="{2:s}">{1:s}</a></li>""", s[:name], joinpath("..", replace(refids[string(s[:module], ".", s[:name])], r"\.md($|#)" => s".html\1")), s[:exported] ? "exported" : "internal")
            end
            println(md, """</ul>""")
        end


        for (exported, ex_label) in exps
            for (typ, ty_label) in labels

                local symbs = filter(x -> x[:exported] == exported && x[:type] == typ, file_symbs)

                if length(symbs) > 0
                    !isempty(ty_label) && println(md, "<h2>$ex_label $(ty_label)s</h2>\n")

                    exported || println(md, """
                        !!! note
                            The following $(lowercase(replace(string(typ), r"^(.+\.)" => "")))s are not exported by default. You may use them by explicitly
                            importing them or by prefixing them with the `$(page.mod).` namespace.

                        """)

                    for s in symbs
                        if typ != Module
                            print(md, "### ")

                            if typ != Base.Docs.Binding
                                print(md, lowercase(string(typ)))
                            end
                            print(md, " `$(typ == Macro ? "@" : "")$(s[:name])`")
                            if get(s, :stype, Any) != Any
                                print(md, " `<:` ", replace_refs("[`$(s[:stype])`]", undocumentedwarning=false))
                            elseif typ == Function && get(s, :extends, "") != ""
                                print(md, " `<:` ", replace_refs("[`$(s[:extends])`]", undocumentedwarning=false))
                            end

                            print(md, " {: ", fully_qualified_object_description(s, includepath=false), "}")

                            print(md, "\n")
                            println(md, """
                                [$(s[:file])#$(s[:line])$(s[:endline] != s[:line] ? "-$(s[:endline])" : "")]($(s[:repo_url])/tree/$(s[:branch])/$(s[:path])/$(s[:file])#L$(s[:line])-$(s[:endline])){: .source-link}
                                """)
                        end

                        s_doc = s[:doc]

                        # Replace references with links to actual functions
                        s_doc = replace(s_doc, Regex("\\[`?(?:\\w+\\.)*[\\w!-]+`?\\]\\(@ref\\)") => m -> replace_refs(m, s[:module], meta=s))

                        # If any <code> blocks match a known symbol, replace with a link to that symbol
                        s_doc = replace(s_doc, r"^`\w+`"m => m -> (r = replace(m, "`" => ""); haskey(refids, r) ? "[$m]($(joinpath("..", refids[r])))" : m))

                        # Fix image URLs since we might be in a directory
                        #s_doc = replace(s_doc, r"(!\[.+?\]\()(\.\./img/)" => s"\1../\2")

                        # If we have a DataType whose documentation does not include subtypes, add them
                        if typ == DataType && !occursin(r"^#### Subtypes$"m, s_doc) && length(subtypes(s[:ref])) > 0
                            s_doc *= """
                                #### Subtypes
                                $(join(["* " * replace_refs("[`$x`]", s[:module], undocumentedwarning=false) for x in subtypes(s[:ref])], "\n"))
                                """
                        end

                        if !isempty(s_doc)
                            println(md, s_doc, "\n---\n")
                        end
                    end
                end
            end
        end

        if page.name == "index" && mod_page_count > 1 && length(file_symbs) < 2
            println(md, """
                ## API Reference
                """)

            p = Page("", "", "")
            for s in symbols
                (s[:module] != page.mod) && continue

                if (p.name != "index" && p.name * ".jl" != s[:file]) || (p.name == "index" && p.mod * ".jl" != s[:file])
                    p = filter(p -> p.mod == s[:module] && ( (p.name != "index" && p.name * ".jl" == s[:file]) || (p.name == "index" && p.mod * ".jl" == s[:file]) ), PAGES)

                    if length(p) == 0
                        p = Page("", "", "")
                        continue
                    else
                        p = p[1]
                    end

                    if p.name == page.name
                        continue
                    end

                    println(md, """

                        * [$(p.title)]($(p.name).md)
                        """)
                end
                println(md, "    * [$(s[:name])]($(joinpath("..", refids[string(s[:module], ".", s[:name])])))")

            end

        end
    end
end


function processStaticPage(page::Page, mdfile_path::AbstractString)
    original_md_file = read(mdfile_path, String)

    # Replace references with links to actual functions
    open(mdfile_path, "w") do md
        replaced_md_file = replace(
                    original_md_file,
                    Regex("\\[`?(?:\\w+\\.)?[\\w!-]+`?\\]\\(@ref\\)") =>
                        m -> replace_refs(
                                m,
                                page.name,
                                addprepath=false,
                                undocumentedwarning=true
                             )
                )
        write(md, replaced_md_file)
    end
end


const MKDOCSY = run_config["config-file"]
const CONFIG  = YAML.load_file(MKDOCSY)
const DOC_SRC = CONFIG["docs_dir"]
const PAGES   = getPages(CONFIG["pages"])

modules = unique(map( p -> p.mod, PAGES ))
symbols = []
mods    = Dict()

for mod in filter( m -> m != ".", modules)
    println("INFO    -  Loading $(mod)")

    eval(Meta.parse("import $mod"))

    local Mod = getfield(Main, Symbol(mod))
    global symbols = symbols ∪ getSymbols(Mod)

    mods[mod] = Mod
end

# Get a list of Modules that do not have their own docs, but have documented objects
# This allows us to add x-links to the module doc file rather than specific functions
undocumented_mods = begin
    local documented_mods        = map(s -> s[:name], filter(s -> s[:type] == Module, symbols))
    local documented_object_mods = unique(map(s -> Dict(
                                            :module   => s[:module],
                                            :name     => string(s[:module]),
                                            :type     => Module,
                                            :stype    => Any,
                                            :ref      => nothing,
                                            :exported => true,
                                            :file     => string(s[:module], ".jl"),
                                            :repo_url => s[:repo_url],
                                            :path     => s[:path],
                                            :branch   => s[:branch],
                                            :line     => 1,
                                            :endline  => 1,
                                            :doc      => "",
                                            :doc_exp  => false
                                        ),
                                        filter(s -> s[:type] != Module, symbols)
                                    ))
    filter(s -> s[:name] ∉ documented_mods, documented_object_mods)
end

# Create a map of documented object => location of documentation as path/file.md#anchor
# Include cases where objects are fully qualified and not qualified (eg, exported objects)
refids  = Dict(
            # Just module for Modules
            map(
                s -> string(s[:module]) => fully_qualified_object_description(s),
                filter(s -> s[:type] == Module, symbols ∪ undocumented_mods)
            )

            ∪

            # Just name, no module for functions, in case one module reexports a function from another
            map(
                s -> string(s[:basename]) => fully_qualified_object_description(s),
                filter(s -> s[:type] == Function, symbols)
            )

            ∪

            # Just name, no module for exported types (also included with module below)
            map(
                s -> string(s[:name]) => fully_qualified_object_description(s),
                filter(s -> s[:type] ∈ [DataType, Base.Docs.Binding] && s[:exported], symbols)
            )

            ∪

            # Full sig including name & parameters
            map(
                s -> string(s[:module], ".", s[:name]) => fully_qualified_object_description(s),
                symbols
            )

            ∪

            # Base name no parameters for functions where basename is different from sig
            map(
                s -> string(s[:module], ".", s[:basename]) => fully_qualified_object_description(s),
                filter(s -> s[:type] == Function && s[:name] != s[:basename], symbols)
            )
          )


cd(@__DIR__) do

    dir_existed = true

    if !isdir(DOC_SRC)
        mkdir(DOC_SRC)
        dir_existed = false
    end

    for page in PAGES

        if page.name == "index" && !isdir(joinpath(DOC_SRC, page.mod))
            mkdir(joinpath(DOC_SRC, page.mod))
        end

        mdfile_path = joinpath(DOC_SRC, page.mod, page.name)

        println("INFO    -  Processing ", page.mod == "." ? "/" : "$(page.mod).", page.name)

        if page.mod == "."
            processStaticPage(page, mdfile_path)
        else
            processModulePage(page, mdfile_path)
        end
    end

    withenv("LC_ALL" => "C.UTF-8", "LANG" => "C.UTF-8") do
        if run_config["add"]
            println("INFO    -  Deploying to gh-pages.")
            success(`mkdocs gh-deploy -c -f $MKDOCSY -v`)
        else
            run(`mkdocs build -c -f $MKDOCSY`)
        end
    end

    for p in filter(p -> p.mod == ".", PAGES)
        path = joinpath(DOC_SRC, p.name)
        println("INFO    -  Resetting $path")
        try
            run(`git checkout -- $path`)
        catch ex
            println("WARN    - $path is not tracked by git")
        end
    end

    if run_config["delete"]
        for p in filter(p -> p.mod != ".", PAGES)
            path = joinpath(DOC_SRC, p.mod, p.name * ".md")
            println("INFO    -  Removing $path")
            rm(path)
        end

        if !dir_existed
            println("INFO    -  Removing $DOC_SRC/")
            rm(DOC_SRC)
        end
    end

end
