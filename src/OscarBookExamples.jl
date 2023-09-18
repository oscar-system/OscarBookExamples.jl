module OscarBookExamples

using Documenter


const oscar_book_dir = "~/papers/oscar-book"
const doc_dir = joinpath(Base.pkgdir(OscarBookExamples), "docs/src")
const obe_dir = Base.pkgdir(OscarBookExamples)
const excluded = [
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_xz",
                  "markwig-ristau-schleis-faithful-tropicalization/eliminate_yz",
                 ]


function roundtrip(;book_dir=nothing, fix=false)
  dir = oscar_book_dir
  if !isnothing(book_dir)
    dir = book_dir
  end

  # 1. Extract code from book
  collect_examples(dir)
  # 2. Run doctests
  Documenter.doctest(OscarBookExamples; fix=true)
  # 3. Update code in book, report errors
  generate_report(; fix=fix)
end
export roundtrip

###############################################################################
###############################################################################
## 
## Reporting on errors
##

function generate_report(; fix::Bool)
  (total, good, bad) = (0,0,0)
  for (root, dirs, files) in walkdir(doc_dir)
    for file in files
      if match(r"\.md", file) !== nothing
        (t,g,b) = generate_diff(root, file; fix=fix)
        total+=t; good+=g; bad+=b
      end
    end
  end
  println("-----------------------------------\nTotal: $total, good: $good, bad: $bad")
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
end

function generate_diff(root::String, filename::String; fix::Bool)
  (total, good, bad) = (0,0,0)
  entire = read(joinpath(root, filename), String)
  examples = split(entire, "## Example")
  for example in examples
    m = match(r"^ `([^`]*)`\n```jldoctest [^`^\n]*\n([^`]*)```", example)
    if m !== nothing
      total += 1
      filename = m.captures[1]
      got = m.captures[2]
      expected = read(filename, String)
      diff = "An ERROR"
      if isnothing(match(r"ERROR", got))
        diff = try_colored_diff(expected, got)
      end
      if got == expected
        good += 1
        println("$filename OK")
      else
        bad += 1
        println("Filename: $filename")
        println("EXPECTED:\n$expected\n--")
        println("GOT:\n$got\n--")
        if diff != "An ERROR"
          println("DIFF:\n$diff\n--")
          if fix
            write(filename, got)
          end
          println()
        else
          @warn "$filename gave an ERROR!"
        end
      end
    end
  end
  return (total, good, bad)
end


###############################################################################
###############################################################################
## 
## Getting examples from book
##

function collect_examples(book_dir::String)
  println("Bookdir is $book_dir")

  for (root, dirs, files) in walkdir(joinpath(expanduser(book_dir), "book/chapters"))
    for file in files
      if file === "chapter.tex"
        examples = get_ordered_examples(root, file)
        if !isempty(examples)
          write_examples_to_markdown(root, file, examples)
        end
      end
    end
  end
end

function write_examples_to_markdown(root::String, filename::String, examples::String)
  decomposed = match(r"([^\/]*)\/([^\/]*)$", root)
  targetfolder = joinpath(doc_dir, decomposed.captures[1])
  mkpath(targetfolder)
  outfilename = joinpath(targetfolder, decomposed.captures[2] * ".md")
  rm(outfilename)
  io = open(outfilename, "a");
  write_preamble(io, decomposed.captures[2])
  write(io, examples)
  close(io)
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
  for line in eachsplit(latex, "\n")
    m = match(r"^[^%]*\\inputminted{([^\}]*)\}\{([^\}]*)\}", line)
    if m !== nothing
      matchtype = m.captures[1]
      matchfilename = m.captures[2]
      matchtype == "jlcon" || @warn "Unknown type $matchtype $matchfilename"
      if matchtype == "jlcon"
        matchfilename = replace(matchfilename, "\\fd/" => "")
        matchfilename = joinpath(root, matchfilename)
        exclude = length(filter(s->occursin(s, matchfilename), excluded)) > 0
        if !exclude
          result *= read_example(matchfilename, label)
        end
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
  is_repl = match(r"^julia>", result) !== nothing
  # Should newline at end be removed?
  if is_repl
    result = "```jldoctest $label\n$result```"
  else
    result = "```julia\n$result```"
  end
  result = "## Example `$file`\n$result\n\n"
  return result
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
