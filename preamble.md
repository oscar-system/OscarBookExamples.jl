```@meta
CurrentModule = OscarBookExamples.Oscar
```

## Example no-read
```jldoctest #LABEL
using Oscar
Oscar.set_seed!(42)
Oscar.randseed!(42)
Main.eval(Meta.parse("using Oscar"))
eval(Oscar.doctestsetup())
nothing
#AUXCODE

# output
```
