# OscarBookExamples

[![Build Status](https://github.com/lkastner/OscarBookExamples.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lkastner/OscarBookExamples.jl/actions/workflows/CI.yml?query=branch%3Amain)


### To test some parts of the book please try the following:

Clone this repository, the oscar-book repository and a create a checkout of the Oscar.jl repo on the `backports-release-1.0` branch.


```julia
$ julia-1.10
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.10.1 (2024-02-13)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

(@v1.10) pkg> activate ./OscarBookExamples.jl/
  Activating project at `~/software/julia/OscarBookExamples.jl`

(OscarBookExamples) pkg> dev ./Oscar-backports.jl/
   Resolving package versions...
    Updating `~/software/julia/OscarBookExamples.jl/Project.toml`
  [e30172f5] + Documenter v1.2.1
  [f1435218] + Oscar v1.0.0-DEV `../Oscar-backports.jl`
  [91a5bcdd] + Plots v1.40.1
    Updating `~/software/julia/OscarBookExamples.jl/Manifest.toml`
  ...

julia> using Oscar, OscarBookExamples
 -----    -----    -----      -      -----   
|     |  |     |  |     |    | |    |     |  
|     |  |        |         |   |   |     |  
|     |   -----   |        |     |  |-----   
|     |        |  |        |-----|  |   |    
|     |  |     |  |     |  |     |  |    |   
 -----    -----    -----   -     -  -     -  

...combining (and extending) ANTIC, GAP, Polymake and Singular
Version 1.0.0-DEV ... 
 ... which comes with absolutely no warranty whatsoever
Type: '?Oscar' for more information
(c) 2019-2024 by The OSCAR Development Team

julia> roundtrip(book_dir="/path/to/the/oscar-book"; only=r"polyhedral-geom")
...
```
The `only` argument is a regex that will select matching parts of the book (by pathname). This will print a summary at the end with blocks of `EXPECTED`, `GOT` and `DIFF` for changes in the output.

It can also be run with the `fix=:report_errors` argument to store the results in an `md` file:
```julia
julia> roundtrip(book_dir="/path/to/the/oscar-book", fix=:report_errors; only=r"polyhedral-geometry")
```

The corresponding file in the book folder, e.g. `/path/to/the/oscar-bookjlcon-testing/cornerstones/polyhedral-geometry.md`, will now contain a diff between the markdown generated from collecting the jlcons and the results of running these blocks as doctests, i.e. look for lines starting with `+` or `-`.


#### Known Issues

Documenter currently fails for all `betti_tables` since it cannot properly detect the input and output.
