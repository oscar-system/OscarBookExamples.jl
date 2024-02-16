module OscarBookExamples

using Documenter
using Oscar

include(joinpath(Oscar.oscardir, "docs/documenter_helpers.jl"))


const obe_dir = Base.pkgdir(OscarBookExamples)
const excluded = [
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_xz",
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_yz",
                  "number-theory/cohenlenstra.jlcon",
                  "bies-turner-string-theory-applications/code-examples/SU5.jlcon",
                  "brandhorst-zach-fibration-hopping/vinberg_2.jlcon",
                  "brandhorst-zach-fibration-hopping/vinberg_3.jlcon",
                  "cornerstones/polyhedral-geometry/ch-benchmark.jlcon",
                  # "cornerstones",
                  # # "cornerstones",
                  # "aga-boehm-hoffmann-markwig-traore",
                  # "bies-kastner-toric-geometry",
                  # "bies-turner-string-theory-applications",
                  # "boehm-breuer-git-fans",
                  # "brandhorst-zach-fibration-hopping",
                  # "breuer-nebe-parker-orthogonal-discriminants",
                  # "decker-schmitt-invariant-theory",
                  # "decker-song-intersection-theory",
                  # "eder-mohr-ideal-theoretic",
                  # "flake-fourier-monomial-bases",
                  # "joswig-kastner-lorenz-confirmable-workflows",
                  # "kuehne-schroeter-matroids",
                  # "markwig-ristau-schleis-faithful-tropicalization",
                  # "rose-sturmfels-telen-tropical-implicitization",
                  # "weber-free-associative-algebras",
                  # "holt-ren-tropical-geometry",
                  # "algebra",
                  # "group",
                  # # "number",
                  # "specialized",
                  # "polyhedral",
                  # Exclude some number theory files:
                  "number-theory/unit_plot.jlcon",
                  "number-theory/intro_plot_lattice.jlcon",
                  "number-theory/intro5_0.jlcon",
                 ]
nexamples = 0
all_examples = String[]
recovered_examples = String[]
marked_examples = String[]

struct DirectorySetup
  doc_dir::String
  oscar_book_dir::String
  temp_dir::String
  jlcon_dir::String
  originals_dir::String
end

function init(;book_dir=nothing)
  obd = Base.expanduser("~/papers/oscar-book")
  if book_dir != nothing
    obd = Base.expanduser(book_dir)
  end
  dd = joinpath(obe_dir, "docs/src")
  for thing in readdir(dd)
    if thing != "index.md"
      rm(joinpath(dd, thing), recursive=true, force=true)
    end
  end
  td = mktempdir()
  println("Tempdir is $td")
  jd = joinpath(obd, "jlcon-testing")
  for thing in readdir(jd)
    if thing != "README.md"
      rm(joinpath(jd, thing), recursive=true, force=true)
    end
  end
  od = joinpath(td, "originals")
  mkdir(od)
  return DirectorySetup(dd, obd, td, jd, od)
end

# Possible values for fix:
# :fix_jlcons Repair the jlcons
# :report_errors Generate a md file highlighting errors
function roundtrip(;book_dir=nothing, fix::Symbol=:off, only=r".*")
  DS = init(;book_dir)

  # Reset some global debug variables
  global nexamples = 0
  global all_examples = String[]
  global recovered_examples = String[]
  global marked_examples = String[]


  # 1. Extract code from book
  collect_examples(DS; fix=fix, only=only)
  # 2. Run doctests
  Documenter.doctest(OscarBookExamples; fix=true)
  # 3. Update code in book, report errors
  generate_report(DS; fix=fix)
  
  if fix == :report_errors
    # 4. Write diff files to oscar book dir
    write_broken_diffs(DS)
  end
end
export roundtrip

###############################################################################
###############################################################################
## 
## Reporting on errors
##

function generate_report(DS::DirectorySetup; fix::Symbol)
  (total, good, bad, error) = (0,0,0,0)
  for (root, dirs, files) in walkdir(DS.doc_dir)
    for file in files
      if (match(r"\.md", file) !== nothing) && (file != "index.md")
        (t,g,b,e) = generate_diffs(DS, root, file; fix=fix)
        total+=t; good+=g; bad+=b; error+=e
        b == 0 || push!(marked_examples, joinpath(root, file))
      end
    end
  end
  println("-----------------------------------\nTotal: $total, good: $good, bad: $bad (error: $error)")
  println(nexamples)
end

function write_broken_diffs(DS::DirectorySetup)
  for mf in marked_examples
    m = match(r"([^/]*.md)", mf)
    filename = m.captures[1]
    original = replace(mf, DS.doc_dir=>DS.originals_dir)
    targetfolder = replace(mf, filename=>"", DS.doc_dir=>DS.jlcon_dir)
    isdir(targetfolder) || mkpath(targetfolder)
    # cmd0 = Cmd(`wdiff $original $mf`, ignorestatus=true)
    # cmd1 = pipeline(cmd0, `colordiff`)
    cmd1 = Cmd(`diff -U 1000 -w --strip-trailing-cr $original $mf`, ignorestatus=true)
    write(joinpath(targetfolder, filename), read(cmd1))
  end
end

function try_colored_diff(DS::DirectorySetup, expected::AbstractString, got::AbstractString)
  expfile = joinpath(DS.temp_dir, "expected")
  gotfile = joinpath(DS.temp_dir, "got")
  write(expfile, expected)
  write(gotfile, got)
  try
    return read(pipeline(Cmd(`wdiff $expfile $gotfile`, ignorestatus=true), `colordiff`), String)
  catch
    return read(Cmd(`diff -w $expfile $gotfile`, ignorestatus=true), String)
  end
end

function update_jlcon(jlcon_filename::AbstractString, result::AbstractString; fix::Symbol, nel::Bool)
  if fix == :fix_jlcons
    if nel
      result = replace(result, r"\n\n" => "\n")
    end
    write(jlcon_filename, result)
  end
end

function record_diff(DS::DirectorySetup, jlcon_filename::AbstractString, got::AbstractString; fix::Symbol)
  expected = read(jlcon_filename, String)
  expected, nel = prepare_jlcon_content(expected)
  diff = "An ERROR"
  result = :good

  if isnothing(match(r"ERROR", got))
    diff = try_colored_diff(DS, expected, got)
  end
  if got == expected
    # println("$jlcon_filename OK")
  else
    result = :bad
    println("Filename: $jlcon_filename")
    println("EXPECTED:\n$expected\n--")
    println("GOT:\n$got\n--")
    if diff != "An ERROR"
      println("DIFF:\n$diff\n--")
      update_jlcon(jlcon_filename, got; fix=fix, nel=nel)
      println()
    else
      result = :error
      @warn "$jlcon_filename gave an ERROR!"
      update_jlcon(jlcon_filename*".fail", got; fix=fix, nel=nel)
    end
  end
  return result
end

function generate_diffs(DS::DirectorySetup, root::String, md_filename::String; fix::Symbol)
  (total, good, bad, error) = (0,0,0,0)
  entire = read(joinpath(root, md_filename), String)
  examples = split(entire, "## Example")
  for example in examples
    m = match(r"^ `([^`]*)`\n```jldoctest [^`^\n]*\n(([^`]*|`(?!``))*)```", example)
    if m !== nothing && isnothing(match(r"no-read", m.captures[1]))
      total += 1
      jlcon_filename = joinpath(DS.oscar_book_dir, m.captures[1])
      push!(recovered_examples, jlcon_filename)
      got, _ = prepare_jlcon_content(m.captures[2])
      state = record_diff(DS, jlcon_filename, got; fix=fix)
      state == :good && (good += 1)
      state == :bad && (bad += 1)
      state == :error && (bad+=1; error += 1)
    end
  end
  return (total, good, bad, error)
end


###############################################################################
###############################################################################
## 
## Getting examples from book
##

function collect_examples(DS::DirectorySetup; fix::Symbol, only=r".*")
  for (root, dirs, files) in walkdir(joinpath(DS.oscar_book_dir, "book/chapters"))
    decomposed = match(r"([^\/]*)\/([^\/]*)$", root)
    label = decomposed.captures[2]
    for file in files
      if file === "chapter.tex"
        examples = get_ordered_examples(DS, root, file, label; only)
        if !isempty(examples)
          (md_folder, md_filename) = write_examples_to_markdown(DS, root, file, examples, label)
          if fix == :report_errors
            target_folder = replace(md_folder, DS.doc_dir=>DS.originals_dir)
            isdir(target_folder) || mkdir(target_folder)
            cp(joinpath(md_folder, md_filename), joinpath(target_folder, md_filename))
          end
        end
      end
    end
  end
end

function write_examples_to_markdown(DS::DirectorySetup, root::String, filename::String, examples::String, label::AbstractString)
  decomposed = match(r"([^\/]*)\/([^\/]*)$", root)
  targetfolder = joinpath(DS.doc_dir, decomposed.captures[1])
  targetfile = decomposed.captures[2] * ".md"
  mkpath(targetfolder)
  outfilename = joinpath(targetfolder, targetfile)
  !isfile(outfilename) || rm(outfilename)
  io = open(outfilename, "a");
  write_preamble(DS, io, root, targetfolder, decomposed.captures[2], label::AbstractString)
  # return
  write(io, examples)
  close(io)
  return (targetfolder, targetfile)
end

function write_preamble(DS::DirectorySetup, io, root::String, targetfolder::String, chapter::AbstractString, label::AbstractString)
  generic = read(joinpath(obe_dir, "preamble.md"), String)
  auxdir = joinpath(root, "auxiliary_code")
  if isdir(auxdir)
    if isfile(joinpath(auxdir, "main.jl"))
      println("There is some auxiliary code!")
      # mkdir(joinpath(targetfolder, "aux_$chapter"))
      includepath = joinpath(targetfolder, "aux_$chapter")
      cp(auxdir, includepath)
      includestuff = """    cd("$includepath") do
                              include("main.jl")
                            end
                     """
      println("IP: $includepath")
      generic = replace(generic, r"#AUXCODE\n"=>includestuff)
    end
  else
    generic = replace(generic, r"#AUXCODE\n"=>"")
  end
  generic = replace(generic, r"jldoctest #LABEL"=>"jldoctest $label")
  write(io, generic)
  write(io, "\n# Examples of $chapter\n\n")
end

function get_ordered_examples(DS::DirectorySetup, root::String, filename::String, label::AbstractString; only=r".*")
  latex = complete_latex(root, filename)
  result = ""
  found_files = String[]
  for line in eachsplit(latex, "\n")
    m = match(r"^[^%]*\\inputminted[^\{]*{([^\}]*)\}\{([^\}]*)\}", line)
    if m !== nothing
      matchtype = m.captures[1]
      matchfilename = m.captures[2]
      matchfilename = replace(matchfilename, "\\fd/" => "")
      matchfilename = joinpath(root, matchfilename)
      matchfilename = replace(matchfilename, DS.oscar_book_dir => "")
      matchfilename = replace(matchfilename, r"^/" => "")
      if !(matchfilename in found_files)
        push!(found_files, matchfilename)
        matchtype == "jlcon" || matchtype == "jl" || @warn "Unknown type $matchtype $matchfilename"
        if matchtype == "jlcon" || matchtype == "jl"
          exclude = filter(s->occursin(s, matchfilename), excluded)
          if length(exclude) == 0 && contains(matchfilename, only)
            result *= read_example(DS, matchfilename, label)
          end
        end
#       else
#         println("$matchfilename already seen!")
      end
    end
  end
  return result
end

function read_example(DS::DirectorySetup, incomplete_file::String, label::AbstractString)
  file = joinpath(DS.oscar_book_dir, incomplete_file)
  if !isfile(file)
    @warn "$file is missing!"
    return ""
  end
  result = read(file, String)
  if isfile(file*".fail")
    rm(file*".fail")
  end
  result, _ = prepare_jlcon_content(result; remove_prefixes=false)
  is_repl = match(r"julia>", result) !== nothing
  # Should newline at end be removed?
  if is_repl
    result = "```jldoctest $label\n$result```"
    push!(all_examples, file)
  else
    result = "```jldoctest $label\n$result\n# output\n```"
  end
  result = "## Example `$incomplete_file`\n$result\n\n"
  global nexamples += 1
  return result
end

function prepare_jlcon_content(content::AbstractString; remove_prefixes=true)
  result = content
  # Get rid of comments in the code
  result = replace(result, r"^#\D.*$"m => "")
  # Get rid of empty lines with whitespaces
  result = replace(result, r"^\s*$"m => "")
  # Get rid of many empty lines
  result = replace(result, r"\n+\n\n" => "\n\n")
  if isnothing(match(r"\n$", result))
    result *= "\n"
  end
  noemptylines = false
  noemptylines =  !isnothing(match(r"julia>.*\njulia>", result))
  if !isnothing(match(r"julia>.*\njulia>", result))
    noemptylines = true
  end
  if !isnothing(match(r"julia>", result))
    result = replace(result, r"^([^j]*|j(?!ulia))*julia>" => "julia>")
    result = replace(result, r"(?<!^)julia>" => "\njulia>")
    result = replace(result, r"\n\n\njulia>" => "\n\njulia>")
    result = replace(result, r"\n\n\njulia>" => "\n\njulia>")
    result = replace(result, r"\n\n\njulia>" => "\n\njulia>")
  end
  if(remove_prefixes)
    result = replace(result, r"(?<!using )Oscar\.([^v])" => s"\1")
    result = replace(result, "Nemo." => "")
  end
  return result, noemptylines
end

function complete_latex(root::String, filename::String)
  result = read(joinpath(root, filename), String)
  while match(r"\\input\{[^\}^\.]*\}", result) !== nothing
    inputs = eachmatch(r"\\input\{([^\}^\.]*)\}", result)
    for m in inputs
      matchstr = m.match
      matchfile = m.captures[1]
      matchfile = read(joinpath(root, matchfile * ".tex"), String)
      result = replace(result, matchstr => matchfile)
    end
  end
  return result
end

end
