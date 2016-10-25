###############################################################################################
#
#  Extract raw Markdown from source files and turn them into docs
# 
#  - Use `names(module)` to get a list of exported symbols from the module
#  - Use __META__ to get all documented symbols along with path to the sourcefile
#  - Use `grep` to get line number in file
#    - because MD.meta only has line for Function and not Module or DataType
#    - because even when there is a line number, it is off by one
#  - Use readlines to read in the source file and pull out docs & end line number
#    - because julia compiles docs to incorrect Markdown objects, and discards the raw MD
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


###############################################################################################
###
### The following constants may be modified for based on your own config
###

# Module to be documented
const mod = "mPulseAPI"

# Temporary location for generated files, change this if you already have a directory called src/
const doc_src = "src"

# YAML config file for mkdocs. This will be generated.
const mkdocsy = "mkdocs.yml"

# Prefix configuration for mkdocs.  Page names will be appended to this
const mkdocs_config = Dict(
    :site_name => "$(mod).jl Documentation",
    :site_url  => "https://SOASTA.github.com/$(mod).jl/",
    :repo_url  => "https://github.com/SOASTA/$(mod).jl/",
    :site_favicon     => "favicon.ico",
    :extra_css => ["css/mkdocs.css"],
    :site_description => "Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.",
    :copyright => "SOASTA, Inc.",
    :docs_dir  => "src",
    :use_directory_urls => false,
    :theme     => "readthedocs",
    :markdown_extensions => [:admonition, :def_list, :attr_list, "toc:\n        permalink: True"],
)

# Don't change this
immutable Page
    name::AbstractString
    title::AbstractString
    pregenerated::Bool

    Page(name::AbstractString, title::AbstractString, pregenerated::Bool=false) = new(name, title, pregenerated)
end

# Pages to build:
# - name
# - title
const pages = Page[
    Page("index", mod),
    Page("apiToken", "How to generate an API Token", true),
    Page("RepositoryAPI", "Repository API"),
    Page("QueryAPI", "Query API"),
    Page("exceptions", "Exceptions"),
    Page("cache_utilities", "Internal Cache Utilities"),
]

###
### End of user configurable section
###
###############################################################################################

using Formatting

eval(parse("using $mod"))

Mod = eval(parse(mod))

function getSymbols(mod::Module; order=[Module, DataType, Function])
    exported = Dict( map( n -> (string(n) => getfield(mod, n)), names(mod) ) )

    declarator = Dict(Function => "(function )?", DataType => "(abstract|immutable|type) ", Module => "module ")

    # Now get all the symbols and mark the exported ones
    function symbol2dict(k)
        k_doc = Docs.doc(k)

        name  = replace(string(k), Regex("^$mod\."), "")

        typ   = typeof(k)

        file  = haskey(k_doc.meta, :path) ?
                    k_doc.meta[:path] :
                length(k_doc.content) == 1 && haskey(k_doc.content[1].meta, :path) ?
                    k_doc.content[1].meta[:path] :
                ""

        api_doc = ""

        if file != ""
            lines = open(readlines, file)
            line = find(x -> ismatch(Regex("^$(declarator[typ])$(name)"), x), lines)
            if length(line) == 0
                println(Regex("^$(declarator[typ]) +$(name)"))
                println(lines)
            end
            line = line[1]

            if typ == Module
                endline = line
                api_doc_start = findnext(lines, "\"\"\"\n", line+1)
                api_doc_end   = findnext(lines, "\"\"\"\n", api_doc_start+1)
                if api_doc_end - api_doc_start > 0
                    api_doc = eval(parse(join(lines[api_doc_start:api_doc_end], "")))
                end
            else
                endline = findnext(lines, "end\n", line)
                api_doc = findprev(lines, "\"\"\"\n", line-2)
                if api_doc > 0
                    api_doc = eval(parse(join(lines[api_doc:line-1], "")))
                end
            end
        else
            line = 0
        end

        api_doc = replace(api_doc, r"^   \*"m, "    *")

        return Dict(
            :name     => name,
            :type     => typ,
            :exported => haskey(exported, replace(string(k), Regex("^$mod\."), "")),
            :file     => replace(file, r"^.*/", ""),
            :line     => line,
            :endline  => endline,
            :doc      => api_doc
        )
    end

    symbols = map( symbol2dict, filter( k -> !isa(k, ObjectIdDict), collect( keys(mod.__META__) ) ) )

    expo_order = Dict(true => "1", false => "2")
    type_order = Dict(zip(order, 1:length(order)))

    sort!(symbols, by = x -> format("{1}.{2}.{3}.{4:04d}.{5}", expo_order[x[:exported]], type_order[x[:type]], x[:file], x[:line], x[:name]))

    return symbols
end

labels = Pair[Module => "", DataType => "Type", Function => "Function"]
exps   = Pair[true => "Exported", false => "Namespaced"]

symbols = getSymbols(Mod)
refids  = Dict(map(s -> (s[:name] => replace(s[:file], r"\.jl$", ".md") * lowercase(string("#", s[:type], "-", s[:name]))), symbols))

function replace_refs(m)
    ref = match(Regex("^\\[(`?(?:$mod\\.)?(\\w+)`?)\\]"), m)

    if ref == nothing
        return m
    end

    txt = ref.captures[1]
    ref = ref.captures[2]

    return "[$txt]($(refids[ref])){: .x-ref}"
end


cd(dirname(@__FILE__)) do

    dir_existed = true

    if !isdir(doc_src)
        mkdir(doc_src)
        dir_existed = false
    end

    open(mkdocsy, "w") do yml

        for (k, v) in mkdocs_config
            print(yml, k, ": ")

            if isa(v, AbstractArray)
                println(yml, mapfoldl(x -> "\n    - $x", *, v))
            else
                println(yml, v)
            end
        end
        println(yml, "pages:")

        for page in pages
    
            println("INFO    -  Processing $(page.name)")
            
            # Only generate pages that are not pre-generated
            page.pregenerated || open(joinpath(doc_src, page.name * ".md"), "w") do f
                println(f, """
                    # $(page.title)

                    """)

                local file_symbs = filter(x -> x[:file] == (page.name == "index" ? mod : page.name) * ".jl", symbols)
                if page.name != "index"
                    for s in file_symbs
                        println(f, "* [$(s[:name])]($(refids[s[:name]]))")
                    end
                end


                for (exported, ex_label) in exps
                    for (typ, ty_label) in labels

                        local symbs = filter(x -> x[:exported] == exported && x[:type] == typ, file_symbs)

                        if length(symbs) > 0
                            !isempty(ty_label) && println(f, "## $ex_label $(ty_label)s")
                
                            exported || println(f, """
                                !!! note
                                    The following methods are not exported by default. You may use them by explicitly
                                    importing them or by prefixing them with the `$(mod).` namespace.

                                """)

                            for s in symbs
                                println(f, """
                                    ##$(typ == Module ? "" : "#") $(lowercase(string(s[:type]))) `$(s[:name])`
                                    [$(s[:file])#$(s[:line])$(s[:endline] != s[:line] ? "-$(s[:endline])" : "")]($(mkdocs_config[:repo_url])tree/master/src/$(s[:file])#L$(s[:line])-L$(s[:endline])){: .source-link}
                                    """)

                                # Replace references with links to actual functions
                                s_doc = replace(s[:doc], Regex("\\[`?(?:$mod\\.)?\\w+`?\\]\\(@ref\\)"), replace_refs)
                                s_doc = replace(s_doc, r"^`(\w+)`"m, m -> (r = replace(m, "`", ""); haskey(refids, r) ? "[$m]($(refids[r]))" : m))

                                # Remove `docs/src/` from any links since we might have that in raw md in our functions
                                s_doc = replace(s_doc, r"/?docs/src/", "")

                                println(f, s_doc, "\n---\n")
                            end
                        end
                    end
                end

                if page.name == "index"
                    println(f, """
                        ## API Reference
                        """)

                    p = Page("", "")
                    for s in symbols
                        (s[:file] == mod * ".jl") && continue

                        if p.name * ".jl" != s[:file]
                            p = filter(p -> p.name * ".jl" == s[:file], pages)

                            if length(p) == 0
                                continue
                            else
                                p = p[1]
                            end

                            println(f, """

                                * [$(p.title)]($(p.name).md)
                                """)
                        end
                        println(f, "    * [$(s[:name])]($(refids[s[:name]]))")
                        
                    end

                end
            end

            println(yml, "    - \"$(page.title)\": \"$(page.name).md\"")
    
        end

    end
    
    run(`mkdocs build -c -f $mkdocsy`)

    if any(x -> x=="--delete", ARGS)
        for p in pages
            path = joinpath(doc_src, p.name * ".md")
            println("INFO    -  Removing $path")
            rm(path)
        end
        
        if !dir_existed
            println("INFO    -  Removing $doc_src/")
            rm(doc_src)
        end
        
        println("INFO    -  Removing $mkdocsy")
        rm(mkdocsy)
    end
    
    if any(x -> x=="--add", ARGS)
        info("Adding all documentation changes in $(doc_src) to this commit.")
        success(`git add $(doc_src)`)
    end
end
