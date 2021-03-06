# State
## Types
```@docs
Stopping.GenericState
Stopping.ListStates
Stopping.NLPAtX
Stopping.LSAtT
```

## General Functions
```@docs
Stopping.update!
Stopping.reinit!
Stopping.copy,
Stopping.compress_state!,
Stopping.copy_compress_state
Stopping.add_to_list!
Stopping.length
Stopping.print
```

# Stopping
## Types
```@docs
Stopping.GenericStopping
Stopping.NLPStopping
Stopping.LS_Stopping
Stopping.LAStopping
Stopping.LACounters
Stopping.StoppingMeta
```

## General Functions
```@docs
Stopping.start!
Stopping.update_and_start!
Stopping.stop!
Stopping.update_and_stop!
Stopping.reinit!
Stopping.fill_in!
Stopping.status
```

## Non-linear admissibility functions
```@docs
Stopping.KKT
Stopping.unconstrained_check
Stopping.unconstrained2nd_check
Stopping.optim_check_bounded
```


## Linear algebra admissibility functions
```@docs
Stopping.linear_system_check
Stopping.normal_equation_check
```

## Line search admissibility functions
```@docs
Stopping.armijo
Stopping.wolfe
Stopping.armijo_wolfe
Stopping.shamanskii_stop
Stopping.goldstein
```
