 #!/usr/bin/env julia
# templates.jl - Julia Project Template Generator
# Usage: julia templates.jl [directory] [project_name]

using Pkg
using TOML
using Dates
using UUIDs  # Explicit import for Julia 1.13+

"""
    Templates module for generating Julia projects from existing code
"""
module Templates#!/usr/bin/env julia
# templates.jl - Simple Working Version for grim
# No module scoping issues#!/usr/bin/env julia
# templates.jl - Simple Working Version for grim
# No module scoping issues

using Pkg, TOML, Dates, UUIDs

function scan_directory(path=".")
    files = Dict(
        :julia => String[],
        :lua => String[],
        :cpp => String[],
        :config => String[],
        :other => String[]
    )

    println("🔍 Scanning: $path")

    for (root, dirs, filenames) in walkdir(path)
        for filename in filenames
            # Skip hidden files
            if startswith(filename, ".") || contains(filename, "build")
                continue
            end

            filepath = joinpath(root, filename)
            rel_path = relpath(filepath, path)
            ext = lowercase(splitext(filename)[2])

            if ext == ".jl"
                push!(files[:julia], rel_path)
            elseif ext == ".lua"
                push!(files[:lua], rel_path)
            elseif ext in [".cpp", ".c", ".h", ".hpp"]
                push!(files[:cpp], rel_path)
            elseif ext in [".toml", ".json", ".yaml"]
                push!(files[:config], rel_path)
            else
                push!(files[:other], rel_path)
            end
        end
    end

    # Show results
    for (category, file_list) in files
        if !isempty(file_list)
            println("  📁 $category: $(length(file_list)) files")
            for file in file_list[1:min(3, length(file_list))]
                println("    • $file")
            end
            if length(file_list) > 3
                println("    ... and $(length(file_list) - 3) more")
            end
        end
    end

    return files
end

function generate_project(source_dir, project_name, author="grim")
    println("📁 Creating project: $project_name")

    # Scan files first
    files = scan_directory(source_dir)

    # Create project structure
    if isdir(project_name)
        print("Directory $project_name exists. Overwrite? (y/N): ")
        response = strip(readline())
        if lowercase(response) != "y"
            println("Cancelled.")
            return
        end
        rm(project_name, recursive=true)
    end

    mkpath(project_name)
    mkpath("$project_name/src")
    mkpath("$project_name/lua")
    mkpath("$project_name/native")

    # Generate Project.toml
    uuid = string(UUIDs.uuid4())
    toml_content = """
name = "$project_name"
uuid = "$uuid"
authors = ["$author <$author@localhost>"]
version = "0.1.0"
description = "Generated Julia project with Lua integration"

[compat]
julia = "1.13"

[deps]
"""

    # Add dependencies based on files found
    if !isempty(files[:lua])
        toml_content *= "LuaCall = \"d1a0f0ad-cd8e-0e8a-b3bb-e6e8a8c7b9c5\"\n"
    end

    if !isempty(files[:cpp])
        toml_content *= "CxxWrap = \"1f15a43c-97ca-5a2a-ae31-89f07a497df4\"\n"
    end

    if !isempty(files[:config])
        toml_content *= "TOML = \"fa267f1f-6049-4f14-aa54-33bafae1ed76\"\n"
        toml_content *= "JSON = \"682c06a0-de6a-54ab-a142-c8b1cf79cde6\"\n"
    end

    toml_content *= "Dates = \"ade2ca70-3891-5945-98fb-dc099432e06a\"\n"

    open("$project_name/Project.toml", "w") do f
        write(f, toml_content)
    end

    # Generate main module
    module_content = """
# $project_name.jl
# Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

module $project_name

using Dates
"""

    if !isempty(files[:lua])
        module_content *= "using LuaCall\n"
    end

    if !isempty(files[:config])
        module_content *= "using TOML, JSON\n"
    end

    module_content *= "\n"

    # Add file loading functions
    if !isempty(files[:lua])
        module_content *= """
# Lua files found in project
const LUA_FILES = [
"""
        for lua_file in files[:lua]
            module_content *= "    \"$lua_file\",\n"
        end
        module_content *= "]\n\n"

        module_content *= """
function load_lua_files()
    L = LuaCall.LuaState()

    for file in LUA_FILES
        lua_path = joinpath("lua", basename(file))
        if isfile(lua_path)
            try
                LuaCall.lua_dofile(L, lua_path)
                println("✅ Loaded: \$lua_path")
            catch e
                @warn "Failed to load \$lua_path: \$e"
            end
        end
    end

    return L
end

"""
    end

    # Main function
    module_content *= """
function main(args=ARGS)
    println("🚀 Starting $project_name...")
    println("🏠 Working directory: \$(pwd())")

"""

    if !isempty(files[:lua])
        module_content *= """    # Load Lua files
    lua_state = load_lua_files()

"""
    end

    module_content *= """    println("✅ $project_name initialized!")
    return 0
end

# Exports
export main"""

    if !isempty(files[:lua])
        module_content *= ", load_lua_files"
    end

    module_content *= "\n\nend # module\n"

    open("$project_name/src/$project_name.jl", "w") do f
        write(f, module_content)
    end

    # Generate executable script
    script_content = """#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)

include("src/$project_name.jl")
using .$project_name

if abspath(PROGRAM_FILE) == @__FILE__
    exit($project_name.main(ARGS))
end
"""

    script_path = "$project_name/$(lowercase(project_name)).jl"
    open(script_path, "w") do f
        write(f, script_content)
    end
    chmod(script_path, 0o755)

    # Copy files
    println("📋 Copying files...")

    # Copy Lua files
    for lua_file in files[:lua]
        src_path = joinpath(source_dir, lua_file)
        dest_path = "$project_name/lua/$(basename(lua_file))"
        if isfile(src_path)
            cp(src_path, dest_path, force=true)
            println("  📄 Copied: $lua_file")
        end
    end

    # Copy C++ files
    for cpp_file in files[:cpp]
        src_path = joinpath(source_dir, cpp_file)
        dest_path = "$project_name/native/$(basename(cpp_file))"
        if isfile(src_path)
            cp(src_path, dest_path, force=true)
            println("  ⚡ Copied: $cpp_file")
        end
    end

    # Generate README
    readme_content = """
# $project_name

Generated Julia project with integrated files.

## Files Found
"""

    for (category, file_list) in files
        if !isempty(file_list)
            readme_content *= "\n### $(uppercasefirst(string(category)))\n"
            for file in file_list
                readme_content *= "- `$file`\n"
            end
        end
    end

    readme_content *= """

## Usage

```bash
cd $project_name
julia $(lowercase(project_name)).jl
```

Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
"""

    open("$project_name/README.md", "w") do f
        write(f, readme_content)
    end

    println("✅ Project created: $project_name")
    println("🚀 Run: cd $project_name && julia $(lowercase(project_name)).jl")
end

function interactive_mode()
    println("🎯 Julia Project Generator")
    println("🏠 Environment: $(get(ENV, "XDG_SESSION_DESKTOP", "KDE"))")
    println("=" ^ 40)

    print("Source directory [.]: ")
    source_dir = strip(readline())
    source_dir = isempty(source_dir) ? "." : source_dir

    print("Project name: ")
    project_name = strip(readline())
    if isempty(project_name)
        project_name = "MyProject"
    end

    print("Author [grim]: ")
    author = strip(readline())
    author = isempty(author) ? "grim" : author

    generate_project(source_dir, project_name, author)
end

# Main execution
function main()
    if length(ARGS) == 0
        interactive_mode()
    elseif ARGS[1] == "scan"
        dir = length(ARGS) >= 2 ? ARGS[2] : "."
        scan_directory(dir)
    elseif ARGS[1] == "generate" && length(ARGS) >= 3
        generate_project(ARGS[2], ARGS[3])
    else
        println("""
Usage:
  julia templates.jl                    # Interactive
  julia templates.jl scan [dir]         # Scan directory
  julia templates.jl generate <dir> <n> # Generate project
        """)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

using Pkg, TOML, Dates, UUIDs

function scan_directory(path=".")
    files = Dict(
        :julia => String[],
        :lua => String[],
        :cpp => String[],
        :config => String[],
        :other => String[]
    )

    println("🔍 Scanning: $path")

    for (root, dirs, filenames) in walkdir(path)
        for filename in filenames
            # Skip hidden files
            if startswith(filename, ".") || contains(filename, "build")
                continue
            end

            filepath = joinpath(root, filename)
            rel_path = relpath(filepath, path)
            ext = lowercase(splitext(filename)[2])

            if ext == ".jl"
                push!(files[:julia], rel_path)
            elseif ext == ".lua"
                push!(files[:lua], rel_path)
            elseif ext in [".cpp", ".c", ".h", ".hpp"]
                push!(files[:cpp], rel_path)
            elseif ext in [".toml", ".json", ".yaml"]
                push!(files[:config], rel_path)
            else
                push!(files[:other], rel_path)
            end
        end
    end

    # Show results
    for (category, file_list) in files
        if !isempty(file_list)
            println("  📁 $category: $(length(file_list)) files")
            for file in file_list[1:min(3, length(file_list))]
                println("    • $file")
            end
            if length(file_list) > 3
                println("    ... and $(length(file_list) - 3) more")
            end
        end
    end

    return files
end

function generate_project(source_dir, project_name, author="grim")
    println("📁 Creating project: $project_name")

    # Scan files first
    files = scan_directory(source_dir)

    # Create project structure
    if isdir(project_name)
        print("Directory $project_name exists. Overwrite? (y/N): ")
        response = strip(readline())
        if lowercase(response) != "y"
            println("Cancelled.")
            return
        end
        rm(project_name, recursive=true)
    end

    mkpath(project_name)
    mkpath("$project_name/src")
    mkpath("$project_name/lua")
    mkpath("$project_name/native")

    # Generate Project.toml
    uuid = string(UUIDs.uuid4())
    toml_content = """
name = "$project_name"
uuid = "$uuid"
authors = ["$author <$author@localhost>"]
version = "0.1.0"
description = "Generated Julia project with Lua integration"

[compat]
julia = "1.13"

[deps]
"""

    # Add dependencies based on files found
    if !isempty(files[:lua])
        toml_content *= "LuaCall = \"d1a0f0ad-cd8e-0e8a-b3bb-e6e8a8c7b9c5\"\n"
    end

    if !isempty(files[:cpp])
        toml_content *= "CxxWrap = \"1f15a43c-97ca-5a2a-ae31-89f07a497df4\"\n"
    end

    if !isempty(files[:config])
        toml_content *= "TOML = \"fa267f1f-6049-4f14-aa54-33bafae1ed76\"\n"
        toml_content *= "JSON = \"682c06a0-de6a-54ab-a142-c8b1cf79cde6\"\n"
    end

    toml_content *= "Dates = \"ade2ca70-3891-5945-98fb-dc099432e06a\"\n"

    open("$project_name/Project.toml", "w") do f
        write(f, toml_content)
    end

    # Generate main module
    module_content = """
# $project_name.jl
# Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

module $project_name

using Dates
"""

    if !isempty(files[:lua])
        module_content *= "using LuaCall\n"
    end

    if !isempty(files[:config])
        module_content *= "using TOML, JSON\n"
    end

    module_content *= "\n"

    # Add file loading functions
    if !isempty(files[:lua])
        module_content *= """
# Lua files found in project
const LUA_FILES = [
"""
        for lua_file in files[:lua]
            module_content *= "    \"$lua_file\",\n"
        end
        module_content *= "]\n\n"

        module_content *= """
function load_lua_files()
    L = LuaCall.LuaState()

    for file in LUA_FILES
        lua_path = joinpath("lua", basename(file))
        if isfile(lua_path)
            try
                LuaCall.lua_dofile(L, lua_path)
                println("✅ Loaded: \$lua_path")
            catch e
                @warn "Failed to load \$lua_path: \$e"
            end
        end
    end

    return L
end

"""
    end

    # Main function
    module_content *= """
function main(args=ARGS)
    println("🚀 Starting $project_name...")
    println("🏠 Working directory: \$(pwd())")

"""

    if !isempty(files[:lua])
        module_content *= """    # Load Lua files
    lua_state = load_lua_files()

"""
    end

    module_content *= """    println("✅ $project_name initialized!")
    return 0
end

# Exports
export main"""

    if !isempty(files[:lua])
        module_content *= ", load_lua_files"
    end

    module_content *= "\n\nend # module\n"

    open("$project_name/src/$project_name.jl", "w") do f
        write(f, module_content)
    end

    # Generate executable script
    script_content = """#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)

include("src/$project_name.jl")
using .$project_name

if abspath(PROGRAM_FILE) == @__FILE__
    exit($project_name.main(ARGS))
end
"""

    script_path = "$project_name/$(lowercase(project_name)).jl"
    open(script_path, "w") do f
        write(f, script_content)
    end
    chmod(script_path, 0o755)

    # Copy files
    println("📋 Copying files...")

    # Copy Lua files
    for lua_file in files[:lua]
        src_path = joinpath(source_dir, lua_file)
        dest_path = "$project_name/lua/$(basename(lua_file))"
        if isfile(src_path)
            cp(src_path, dest_path)
            println("  📄 Copied: $lua_file")
        end
    end

    # Copy C++ files
    for cpp_file in files[:cpp]
        src_path = joinpath(source_dir, cpp_file)
        dest_path = "$project_name/native/$(basename(cpp_file))"
        if isfile(src_path)
            cp(src_path, dest_path)
            println("  ⚡ Copied: $cpp_file")
        end
    end

    # Generate README
    readme_content = """
# $project_name

Generated Julia project with integrated files.

## Files Found
"""

    for (category, file_list) in files
        if !isempty(file_list)
            readme_content *= "\n### $(uppercasefirst(string(category)))\n"
            for file in file_list
                readme_content *= "- `$file`\n"
            end
        end
    end

    readme_content *= """

## Usage

```bash
cd $project_name
julia $(lowercase(project_name)).jl
```

Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
"""

    open("$project_name/README.md", "w") do f
        write(f, readme_content)
    end

    println("✅ Project created: $project_name")
    println("🚀 Run: cd $project_name && julia $(lowercase(project_name)).jl")
end

function interactive_mode()
    println("🎯 Julia Project Generator")
    println("🏠 Environment: $(get(ENV, "XDG_SESSION_DESKTOP", "KDE"))")
    println("=" ^ 40)

    print("Source directory [.]: ")
    source_dir = strip(readline())
    source_dir = isempty(source_dir) ? "." : source_dir

    print("Project name: ")
    project_name = strip(readline())
    if isempty(project_name)
        project_name = "MyProject"
    end

    print("Author [grim]: ")
    author = strip(readline())
    author = isempty(author) ? "grim" : author

    generate_project(source_dir, project_name, author)
end

# Main execution
function main()
    if length(ARGS) == 0
        interactive_mode()
    elseif ARGS[1] == "scan"
        dir = length(ARGS) >= 2 ? ARGS[2] : "."
        scan_directory(dir)
    elseif ARGS[1] == "generate" && length(ARGS) >= 3
        generate_project(ARGS[2], ARGS[3])
    else
        println("""
Usage:
  julia templates.jl                    # Interactive
  julia templates.jl scan [dir]         # Scan directory
  julia templates.jl generate <dir> <n> # Generate project
        """)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

using Pkg, TOML, Dates, UUIDs

export scan_directory, generate_project, create_from_template, TemplateConfig

"""
Configuration structure for template generation
"""
struct TemplateConfig
    project_name::String
    author::String
    email::String
    license::String
    julia_version::String
    description::String

    function TemplateConfig(;
        project_name="MyProject",
        author="Developer",
        email="dev@example.com",
        license="MIT",
        julia_version="1.13",
        description="A Julia project"
    )
        new(project_name, author, email, license, julia_version, description)
    end
end

"""
    scan_directory(path::String) -> Dict

Scan a directory and categorize files for project generation
"""
function scan_directory(path::String=".")
    if !isdir(path)
        error("Directory $path does not exist")
    end

    files = Dict(
        :julia => String[],
        :lua => String[],
        :cpp => String[],
        :headers => String[],
        :config => String[],
        :docs => String[],
        :other => String[]
    )

    println("🔍 Scanning directory: $path")

    for (root, dirs, filenames) in walkdir(path)
        for filename in filenames
            filepath = joinpath(root, filename)
            relpath = relpath(filepath, path)

            # Skip hidden files and build directories
            if startswith(basename(filename), ".") ||
               contains(relpath, "build") ||
               contains(relpath, ".git")
                continue
            end

            # Categorize by extension
            ext = lowercase(splitext(filename)[2])
            if ext == ".jl"
                push!(files[:julia], relpath)
            elseif ext == ".lua"
                push!(files[:lua], relpath)
            elseif ext in [".cpp", ".cc", ".cxx"]
                push!(files[:cpp], relpath)
            elseif ext in [".h", ".hpp", ".hxx"]
                push!(files[:headers], relpath)
            elseif ext in [".toml", ".json", ".yaml", ".yml", ".ini"]
                push!(files[:config], relpath)
            elseif ext in [".md", ".rst", ".txt"]
                push!(files[:docs], relpath)
            else
                push!(files[:other], relpath)
            end
        end
    end

    # Print summary
    for (category, file_list) in files
        if !isempty(file_list)
            println("  📁 $category: $(length(file_list)) files")
            for file in file_list[1:min(3, length(file_list))]
                println("    • $file")
            end
            if length(file_list) > 3
                println("    ... and $(length(file_list) - 3) more")
            end
        end
    end

    return files
end

"""
    generate_project_toml(config::TemplateConfig, files::Dict) -> String

Generate Project.toml content based on scanned files
"""
function generate_project_toml(config::TemplateConfig, files::Dict)
    # Generate UUID
    uuid = string(UUIDs.uuid4())

    toml_content = """
name = "$(config.project_name)"
uuid = "$uuid"
authors = ["$(config.author) <$(config.email)>"]
version = "0.1.0"
description = "$(config.description)"

[compat]
julia = "$(config.julia_version)"

[deps]
"""

    # Add dependencies based on file types
    deps = String[]

    if !isempty(files[:lua])
        push!(deps, "LuaCall = \"d1a0f0ad-cd8e-0e8a-b3bb-e6e8a8c7b9c5\"")
    end

    if !isempty(files[:cpp]) || !isempty(files[:headers])
        push!(deps, "CxxWrap = \"1f15a43c-97ca-5a2a-ae31-89f07a497df4\"")
    end

    if !isempty(files[:config])
        push!(deps, "TOML = \"fa267f1f-6049-4f14-aa54-33bafae1ed76\"")
        push!(deps, "JSON = \"682c06a0-de6a-54ab-a142-c8b1cf79cde6\"")
    end

    # Always useful packages
    push!(deps, "Pkg = \"44cfe95a-1eb2-52ea-b672-e2afdf69b78f\"")

    for dep in deps
        toml_content *= dep * "\n"
    end

    return toml_content
end

"""
    generate_main_module(config::TemplateConfig, files::Dict) -> String

Generate main Julia module based on scanned files
"""
function generate_main_module(config::TemplateConfig, files::Dict)
    module_content = """
# $(config.project_name).jl
# Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

module $(config.project_name)

using Pkg
"""

    # Add imports based on file types
    if !isempty(files[:lua])
        module_content *= "using LuaCall\n"
    end

    if !isempty(files[:cpp]) || !isempty(files[:headers])
        module_content *= "using CxxWrap\n"
    end

    if !isempty(files[:config])
        module_content *= "using TOML, JSON\n"
    end

    module_content *= "\n"

    # Add file loading functions
    if !isempty(files[:lua])
        module_content *= """
# Lua integration
const LUA_FILES = [
"""
        for lua_file in files[:lua]
            module_content *= "    \"$lua_file\",\n"
        end
        module_content *= "]\n\n"

        module_content *= """
function load_lua_files()
    L = LuaCall.LuaState()
    for file in LUA_FILES
        if isfile(file)
            LuaCall.lua_dofile(L, file)
            println("✅ Loaded Lua file: \$file")
        else
            @warn "Lua file not found: \$file"
        end
    end
    return L
end

"""
    end

    if !isempty(files[:config])
        module_content *= """
# Configuration loading
function load_config(filepath::String)
    if endswith(filepath, ".toml")
        return TOML.parsefile(filepath)
    elseif endswith(filepath, ".json")
        return JSON.parsefile(filepath)
    else
        error("Unsupported config format: \$filepath")
    end
end

"""
    end

    # Add main function
    module_content *= """
# Main entry point
function main(args=ARGS)
    println("🚀 Starting $(config.project_name)...")

"""

    if !isempty(files[:lua])
        module_content *= """    # Load Lua files
    lua_state = load_lua_files()

"""
    end

    if !isempty(files[:config])
        module_content *= """    # Load configuration
    config_files = filter(f -> endswith(f, ".toml") || endswith(f, ".json"), readdir("."))
    for config_file in config_files
        try
            config = load_config(config_file)
            println("📋 Loaded config: \$config_file")
        catch e
            @warn "Failed to load config \$config_file: \$e"
        end
    end

"""
    end

    module_content *= """    println("✅ $(config.project_name) initialized successfully!")
    return 0
end

# Export main functions
export main"""

    if !isempty(files[:lua])
        module_content *= ", load_lua_files"
    end

    if !isempty(files[:config])
        module_content *= ", load_config"
    end

    module_content *= "\n\nend # module\n"

    return module_content
end

"""
    create_executable_script(config::TemplateConfig) -> String

Create executable Julia script
"""
function create_executable_script(config::TemplateConfig)
    script_content = """#!/usr/bin/env julia

# Executable script for $(config.project_name)
# Usage: julia $(lowercase(config.project_name)).jl [args...]

using Pkg

# Activate project environment
Pkg.activate(@__DIR__)

# Load main module
include("src/$(config.project_name).jl")
using .$(config.project_name)

# Run main function
if abspath(PROGRAM_FILE) == @__FILE__
    exit($(config.project_name).main(ARGS))
end
"""
    return script_content
end

"""
    generate_readme(config::TemplateConfig, files::Dict) -> String

Generate README.md for the project
"""
function generate_readme(config::TemplateConfig, files::Dict)
    readme_content = """
# $(config.project_name)

$(config.description)

## Generated Project Structure

This project was automatically generated from existing files:

"""

    for (category, file_list) in files
        if !isempty(file_list)
            readme_content *= "### $(uppercasefirst(string(category))) Files\n"
            for file in file_list
                readme_content *= "- `$file`\n"
            end
            readme_content *= "\n"
        end
    end

    readme_content *= """
## Installation

```bash
# Clone or download this project
cd $(config.project_name)

# Install dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Usage

```bash
# Run the main script
julia $(lowercase(config.project_name)).jl

# Or use as a package
julia --project=. -e "using $(config.project_name); $(config.project_name).main()"
```

## Development

```bash
# Activate project environment
julia --project=.

# In Julia REPL:
julia> using $(config.project_name)
julia> $(config.project_name).main()
```

Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
"""

    return readme_content
end

"""
    generate_project(source_dir::String, config::TemplateConfig) -> String

Generate a complete Julia project from existing files
"""
function generate_project(source_dir::String, config::TemplateConfig)
    # Scan source directory
    files = scan_directory(source_dir)

    # Create project directory
    project_dir = config.project_name
    if isdir(project_dir)
        print("Directory $project_dir exists. Overwrite? (y/N): ")
        response = readline()
        if lowercase(strip(response)) != "y"
            println("Cancelled.")
            return project_dir
        end
        rm(project_dir, recursive=true)
    end

    println("📁 Creating project directory: $project_dir")
    mkpath(project_dir)
    mkpath(joinpath(project_dir, "src"))
    mkpath(joinpath(project_dir, "test"))
    mkpath(joinpath(project_dir, "docs"))

    # Generate Project.toml
    println("📝 Generating Project.toml...")
    project_toml = generate_project_toml(config, files)
    open(joinpath(project_dir, "Project.toml"), "w") do f
        write(f, project_toml)
    end

    # Generate main module
    println("📝 Generating main module...")
    main_module = generate_main_module(config, files)
    open(joinpath(project_dir, "src", "$(config.project_name).jl"), "w") do f
        write(f, main_module)
    end

    # Generate executable script
    println("📝 Generating executable script...")
    executable_script = create_executable_script(config)
    script_path = joinpath(project_dir, "$(lowercase(config.project_name)).jl")
    open(script_path, "w") do f
        write(f, executable_script)
    end
    chmod(script_path, 0o755)  # Make executable

    # Generate README
    println("📝 Generating README.md...")
    readme = generate_readme(config, files)
    open(joinpath(project_dir, "README.md"), "w") do f
        write(f, readme)
    end

    # Copy original files
    println("📋 Copying original files...")
    original_dir = joinpath(project_dir, "original")
    mkpath(original_dir)

    for (category, file_list) in files
        if !isempty(file_list)
            category_dir = joinpath(original_dir, string(category))
            mkpath(category_dir)
            for file in file_list
                src_path = joinpath(source_dir, file)
                dest_path = joinpath(category_dir, basename(file))
                if isfile(src_path)
                    cp(src_path, dest_path)
                end
            end
        end
    end

    # Generate test file
    test_content = """
using Test
using $(config.project_name)

@testset "$(config.project_name) Tests" begin
    @test $(config.project_name).main([]) == 0
end
"""
    open(joinpath(project_dir, "test", "runtests.jl"), "w") do f
        write(f, test_content)
    end

    println("✅ Project generated successfully!")
    println("📁 Project location: $project_dir")
    println("🚀 Run with: cd $project_dir && julia $(lowercase(config.project_name)).jl")

    return project_dir
end

"""
Interactive project generation
"""
function interactive_generate()
    println("🎯 Interactive Julia Project Generator")
    println("=====================================")

    # Get source directory
    print("Source directory (default: current directory): ")
    source_dir = strip(readline())
    if isempty(source_dir)
        source_dir = "."
    end

    if !isdir(source_dir)
        error("Directory $source_dir does not exist")
    end

    # Get project configuration
    print("Project name: ")
    project_name = strip(readline())
    if isempty(project_name)
        project_name = "MyProject"
    end

    print("Author name (default: $ENV[\"USER\"]): ")
    author = strip(readline())
    if isempty(author)
        author = get(ENV, "USER", "Developer")
    end

    print("Email (default: user@example.com): ")
    email = strip(readline())
    if isempty(email)
        email = "user@example.com"
    end

    print("Description: ")
    description = strip(readline())
    if isempty(description)
        description = "A Julia project generated from existing code"
    end

    # Create configuration
    config = TemplateConfig(
        project_name=project_name,
        author=author,
        email=email,
        description=description
    )

    # Generate project
    return generate_project(source_dir, config)
end

end # module Templates

# Command line interface
function main()
    if length(ARGS) == 0
        # Interactive mode
        Templates.interactive_generate()
    elseif ARGS[1] == "scan"
        # Scan mode
        dir = length(ARGS) >= 2 ? ARGS[2] : "."
        Templates.scan_directory(dir)
    elseif ARGS[1] == "generate"
        # Generate mode
        if length(ARGS) < 3
            println("Usage: julia templates.jl generate <source_dir> <project_name>")
            return 1
        end

        source_dir = ARGS[2]
        project_name = ARGS[3]

        config = Templates.TemplateConfig(project_name=project_name)
        Templates.generate_project(source_dir, config)
    else
        println("""
Julia Project Template Generator

Usage:
  julia templates.jl                           # Interactive mode
  julia templates.jl scan [directory]          # Scan directory
  julia templates.jl generate <dir> <name>     # Generate project

Examples:
  julia templates.jl scan .                    # Scan current directory
  julia templates.jl generate . MyProject     # Generate project from current directory
        """)
    end

    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
