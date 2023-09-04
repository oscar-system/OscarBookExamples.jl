module OscarBookExamples

# Write your package code here.


const oscar_book_dir = "~/papers/oscar-book"
const doc_dir = joinpath(Base.pkgdir(OscarBookExamples), "docs/src")
const obe_dir = Base.pkgdir(OscarBookExamples)

function collect_examples(; dir=nothing)
  book_dir = oscar_book_dir
  if !isnothing(dir)
    book_dir = dir
  end
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
  println("wetm: $filename")
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
  result = ""
  for line in eachsplit(latex, "\n")
    m = match(r"^[^%]*\\inputminted{([^\}]*)\}\{([^\}]*)\}", line)
    if m !== nothing
      println(m.match)
      matchtype = m.captures[1]
      matchfilename = m.captures[2]
      matchtype == "jlcon" || @warn "Unknown type $matchtype $matchfilename"
      if matchtype == "jlcon"
        matchfilename = replace(matchfilename, "\\fd/" => "")
        matchfilename = joinpath(root, matchfilename)
        result *= read_example(matchfilename)
      end
    end
  end
  return result
end

function read_example(file::String)
  result = read(file, String)
  is_repl = match(r"^julia>", result) !== nothing
  if is_repl
    result = "```jldoctest\n$result\n```"
  else
    result = "```julia\n$result\n```"
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
