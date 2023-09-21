module OscarBookExamples

using Documenter


const oscar_book_dir = "~/papers/oscar-book"
const doc_dir = joinpath(Base.pkgdir(OscarBookExamples), "docs/src")
const obe_dir = Base.pkgdir(OscarBookExamples)
const excluded = [
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_xz",
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_yz",
                  "number-theory/cohenlenstra.jlcon",
                 ]
nexamples = 0
all_examples = String[]
recovered_examples = String[]
marked_examples = String[]


function roundtrip(;book_dir=nothing, fix::Symbol=:off)
  dir = expanduser(oscar_book_dir)
  if !isnothing(book_dir)
    dir = book_dir
  end

  # Reset some global debug variables
  global nexamples = 0
  global all_examples = String[]
  global recovered_examples = String[]
  global marked_examples = String[]
  # Clean output dir
  for thing in readdir(doc_dir)
    if thing != "index.md"
      rm(joinpath(doc_dir, thing), recursive=true, force=true)
    end
  end
  originals_dir = mktempdir()
  jlcon_dir = joinpath(dir, "jlcon-testing")
  for thing in readdir(jlcon_dir)
    println("Thing is $thing")
    if thing != "README.md"
      rm(joinpath(jlcon_dir, thing), recursive=true, force=true)
    end
  end


  # 1. Extract code from book
  collect_examples(dir, originals_dir; fix=fix)
  # 2. Run doctests
  Documenter.doctest(OscarBookExamples; fix=true)
  # 3. Update code in book, report errors
  generate_report(; fix=fix)
  
  if fix == :report_errors
    # 4. Write diff files to oscar book dir
    write_broken_dffs(jlcon_dir, originals_dir)
  end
end
export roundtrip

###############################################################################
###############################################################################
## 
## Reporting on errors
##

function generate_report(;fix::Symbol)
  (total, good, bad, error) = (0,0,0,0)
  for (root, dirs, files) in walkdir(doc_dir)
    for file in files
      if (match(r"\.md", file) !== nothing) && (file != "index.md")
        (t,g,b,e) = generate_diffs(root, file; fix=fix)
        total+=t; good+=g; bad+=b; error+=e
        b == 0 || push!(marked_examples, joinpath(root, file))
      end
    end
  end
  println("-----------------------------------\nTotal: $total, good: $good, bad: $bad (error: $error)")
  println(nexamples)
end

function write_broken_dffs(jlcon_dir::String, originals_dir::String)
  for mf in marked_examples
    m = match(r"([^/]*.md)", mf)
    filename = m.captures[1]
    original = replace(mf, doc_dir=>originals_dir)
    targetfolder = replace(mf, filename=>"", doc_dir=>jlcon_dir)
    isdir(targetfolder) || mkpath(targetfolder)
    cmd0 = Cmd(`wdiff $original $mf`, ignorestatus=true)
    cmd1 = pipeline(cmd0, `colordiff`)
    write(joinpath(targetfolder, filename), read(cmd1))
  end
end

function try_colored_diff(expected::AbstractString, got::AbstractString)
  diffdir = mktempdir()
  expfile = joinpath(diffdir, "expected")
  gotfile = joinpath(diffdir, "got")
  write(expfile, expected)
  write(gotfile, got)
  try
    return read(pipeline(Cmd(`wdiff $expfile $gotfile`, ignorestatus=true), `colordiff`), String)
  catch
    return read(Cmd(`diff $expfile $gotfile`, ignorestatus=true), String)
  end
  rm(diffdir, recursive=true, force=true)
end

function update_jlcon(jlcon_filename::AbstractString, result::AbstractString; fix::Symbol, nel::Bool)
  if fix == :fix_jlcons
    if nel
      result = replace(result, r"\n\n" => "\n")
    end
    write(jlcon_filename, result)
  end
end

function record_diff(jlcon_filename::AbstractString, got::AbstractString; fix::Symbol)
  expected = read(jlcon_filename, String)
  expected, nel = prepare_jlcon_content(expected)
  diff = "An ERROR"
  result = :good

  if isnothing(match(r"ERROR", got))
    diff = try_colored_diff(expected, got)
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

function generate_diffs(root::String, md_filename::String; fix::Symbol)
  (total, good, bad, error) = (0,0,0,0)
  entire = read(joinpath(root, md_filename), String)
  examples = split(entire, "## Example")
  for example in examples
    m = match(r"^ `([^`]*)`\n```jldoctest [^`^\n]*\n(([^`]*|`(?!``))*)```", example)
    if m !== nothing
      total += 1
      jlcon_filename = m.captures[1]
      push!(recovered_examples, jlcon_filename)
      got = m.captures[2]
      state = record_diff(jlcon_filename, got; fix=fix)
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

function collect_examples(book_dir::String, originals_dir::String; fix::Symbol)
  println("Bookdir is $book_dir")

  for (root, dirs, files) in walkdir(joinpath(expanduser(book_dir), "book/chapters"))
    for file in files
      if file === "chapter.tex"
        examples = get_ordered_examples(root, file)
        if !isempty(examples)
          (md_folder, md_filename) = write_examples_to_markdown(root, file, examples)
          if fix == :report_errors
            target_folder = replace(md_folder, doc_dir=>originals_dir)
            isdir(target_folder) || mkdir(target_folder)
            cp(joinpath(md_folder, md_filename), joinpath(target_folder, md_filename))
          end
        end
      end
    end
  end
end

function write_examples_to_markdown(root::String, filename::String, examples::String)
  decomposed = match(r"([^\/]*)\/([^\/]*)$", root)
  targetfolder = joinpath(doc_dir, decomposed.captures[1])
  targetfile = decomposed.captures[2] * ".md"
  mkpath(targetfolder)
  outfilename = joinpath(targetfolder, targetfile)
  !isfile(outfilename) || rm(outfilename)
  io = open(outfilename, "a");
  write_preamble(io, decomposed.captures[2])
  write(io, examples)
  close(io)
  return (targetfolder, targetfile)
end

function write_preamble(io, chapter::AbstractString)
  generic = read(joinpath(obe_dir, "preamble.md"), String)
  write(io, generic)
  write(io, "\n# Examples of $chapter\n\n")
end

function get_ordered_examples(root::String, filename::String)
  latex = complete_latex(root, filename)
  decomposed = match(r"([^\/]*)\/([^\/]*)$", root)
  label = decomposed.captures[2]
  result = ""
  found_files = String[]
  for line in eachsplit(latex, "\n")
    m = match(r"^[^%]*\\inputminted[^\{]*{([^\}]*)\}\{([^\}]*)\}", line)
    if m !== nothing
      matchtype = m.captures[1]
      matchfilename = m.captures[2]
      matchfilename = replace(matchfilename, "\\fd/" => "")
      matchfilename = joinpath(root, matchfilename)
      if !(matchfilename in found_files)
        push!(found_files, matchfilename)
        matchtype == "jlcon" || @warn "Unknown type $matchtype $matchfilename"
        if matchtype == "jlcon"
          exclude = length(filter(s->occursin(s, matchfilename), excluded)) > 0
          if !exclude
            result *= read_example(matchfilename, label)
          end
        end
      else
        println("$matchfilename already seen!")
      end
    end
  end
  return result
end

function read_example(file::String, label::AbstractString)
  if !isfile(file)
    @warn "$file is missing!"
    return ""
  end
  result = read(file, String)
  if isfile(file*".fail")
    rm(file*".fail")
  end
  result, _ = prepare_jlcon_content(result)
  is_repl = match(r"^julia>", result) !== nothing
  # Should newline at end be removed?
  if is_repl
    result = "```jldoctest $label\n$result```"
    push!(all_examples, file)
  else
    result = "```julia\n$result```"
  end
  result = "## Example `$file`\n$result\n\n"
  global nexamples += 1
  return result
end

function prepare_jlcon_content(content::String)
  result = content
  if isnothing(match(r"\n$", result))
    result *= "\n"
  end
  noemptylines = false
  if !isnothing(match(r"julia>.*\njulia>", result))
    # println("Does not use empty lines!\n$result")
    noemptylines = true
    result = replace(result, r"(julia>.*)\njulia>" => s"\1\n\njulia>")
    result = replace(result, r"(julia>.*)\njulia>" => s"\1\n\njulia>")
    result = replace(result, r"(julia>.*)\njulia>" => s"\1\n\njulia>")
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
