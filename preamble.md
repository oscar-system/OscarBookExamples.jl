```@meta
CurrentModule = OscarBookExamples.Oscar
```

## Example no-read
```jldoctest #LABEL
using Oscar
Main.eval(Meta.parse("using Oscar"))
eval(Oscar.doctestsetup())
#AUXCODE

Oscar.set_seed!(42)
Oscar.randseed!(42)
nothing
# output
```
