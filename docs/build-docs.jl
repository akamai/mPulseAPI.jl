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
    :site_description => "Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.",
    :copyright => "SOASTA, Inc.",
    :docs_dir  => "src",
    :use_directory_urls => false,
    :theme     => "readthedocs",
    :markdown_extensions => [:admonition, :def_list, :attr_list],
)

# Don't change this
immutable Page
    name::AbstractString
    title::AbstractString
end

# Pages to build:
# - name
# - title
const pages = Page[
    Page("index", mod),
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
    # Let's get all exported thingies
    io = IOBuffer()
    whos(io, mod)
    exported = takebuf_string(io)
    exported = Dict(
        map(
            m -> (m.captures[1] => eval(parse(m.captures[2]))),
            map(
                o -> match(r"^ *(\w+) +\d+ \w+ +(\w+)", o),
                filter(
                    x -> !isempty(x),
                    split(
                        exported,
                        "\n"
                    )
                )
            )
        )
    )

    declarator = Dict(Function => "(function )?", DataType => "(abstract|immutable|type) ", Module => "module ")

    # Now get all the thingies and mark the exported ones
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
                api_doc = findnext(lines, "\"\"\"\n", line+2)
                if api_doc > 0
                    api_doc = eval(parse(join(lines[line+1:api_doc], "")))
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
            
            open(joinpath(doc_src, page.name * ".md"), "w") do f
                println(f, """
                    # $(page.title)

                    """)


                for (exported, ex_label) in exps
                    for (typ, ty_label) in labels

                        symbs = filter(x -> x[:file] == (page.name == "index" ? mod : page.name) * ".jl" && x[:exported] == exported && x[:type] == typ, symbols)

                        if length(symbs) > 0
                            !isempty(ty_label) && println(f, "## $ex_label $(ty_label)s")
                
                            exported || println(f, """ 
                                !!! note
                                    The following methods are not exported by default. You may use them by explicitly
                                    importing them or by prefixing them with the `$(mod).` namespace.

                                """)

                            for s in symbs
                                println(f, """
                                    [$(s[:file])#$(s[:line])$(s[:endline] != s[:line] ? "-$(s[:endline])" : "")]($(mkdocs_config[:repo_url])tree/master/src/$(s[:file])#L$(s[:line])-L$(s[:endline])){: .source-link style="float:right;font-size:0.8em;"}
                                    ##$(typ == Module ? "" : "#") $(lowercase(string(s[:type]))) `$(s[:name])`
                                    """)

                                println(f, s[:doc], "\n---\n")
                            end
                        end
                    end
                end

                if page.name == "index"
                    println(f, """
                        ## Table of Contents
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
                        println(f, "    * [$(s[:name])]($(p.name).md#$(lowercase(string(s[:type], "-", s[:name]))))")
                        
                    end

                end
            end

            println(yml, "    - \"$(page.title)\": \"$(page.name).md\"")
    
        end

    end
    
    run(`mkdocs build -c -f $mkdocsy`)

    delete_after = any(x -> x=="--no-delete", ARGS) ? false : true

    if delete_after
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
    
    #info("Adding all documentation changes in $(doc_src) to this commit.")
    #success(`git add $(doc_src)`) || exit(1)
end
