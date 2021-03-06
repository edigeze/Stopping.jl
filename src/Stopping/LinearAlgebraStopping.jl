"""
Type: LAStopping

Methods: start!, stop!, update\\_and\\_start!, update\\_and\\_stop!, fill_in!, reinit!, status
linear\\_system\\_check, normal\\_equation\\_check

Specialization of GenericStopping. Stopping structure for linear algebra
solving either

``Ax = b``

or

``min\\_{x} \\tfrac{1}{2}\\|Ax - b\\|^2``.

Attributes:
- pb         : a problem using LLSModel (designed for linear least square problem, see https://github.com/JuliaSmoothOptimizers/NLPModels.jl/blob/master/src/lls_model.jl )
- state      : The information relative to the problem, see GenericState
- (opt) meta : Metadata relative to stopping criterion, see *StoppingMeta*.
- (opt) main_stp : Stopping of the main loop in case we consider a Stopping
                          of a subproblem.
                          If not a subproblem, then nothing.
- (opt) listofstates : ListStates designed to store the history of States.
- (opt) user_specific_struct : Contains any structure designed by the user.

`LAStopping(:: LLSModel, :: AbstractState; meta :: AbstractStoppingMeta = StoppingMeta() main_stp :: Union{AbstractStopping, Nothing} = nothing, user_specific_struct :: Any = nothing, kwargs...)`

Note:
- Kwargs are forwarded to the classical constructor.
- Not specific State targeted
- State don't necessarily keep track of evals
- Evals are checked only for pb.A being a LinearOperator
- zero_start is true if 0 is the initial guess (not check automatically)
- LLSModel counter follow NLSCounters (see _init_max_counters_NLS in NLPStoppingmod.jl)
- By default, meta.max\\_cntrs is initialized with an NLSCounters

There is additional constructors:

`LAStopping(:: Union{AbstractLinearOperator, AbstractMatrix}, :: AbstractVector, kwargs...)`
`LAStopping(:: Union{AbstractLinearOperator, AbstractMatrix}, :: AbstractVector, :: AbstractState, kwargs...)`

See also GenericStopping, NLPStopping, LS\\_Stopping, linear\\_system\\_check, normal\\_equation\\_check
 """
 mutable struct LAStopping{T <: AbstractState, Pb <: Any} <: AbstractStopping

     # problem
     pb                   :: Pb
     # Common parameters
     meta                 :: AbstractStoppingMeta
     # current state of the problem
     current_state        :: T
     # Stopping of the main problem, or nothing
     main_stp             :: Union{AbstractStopping, Nothing}
     # History of states
     listofstates         :: Union{ListStates, Nothing}
     # User-specific structure
     user_specific_struct :: Any

     #zero is initial point
     zero_start           :: Bool

     function LAStopping(pb             :: Pb,
                         current_state  :: T;
                         meta           :: AbstractStoppingMeta = StoppingMeta(max_cntrs = _init_max_counters_NLS(), optimality_check = linear_system_check),
                         main_stp       :: Union{AbstractStopping, Nothing} = nothing,
                         list           :: Union{ListStates, Nothing} = nothing,
                         user_specific_struct :: Any = nothing,
                         zero_start     :: Bool = false,
                         kwargs...) where {T <: AbstractState, Pb <: Any}

         if !(isempty(kwargs))
            meta = StoppingMeta(;max_cntrs = _init_max_counters_NLS(), optimality_check = linear_system_check, kwargs...)
         end

         return new{T,Pb}(pb, meta, current_state, main_stp, list, user_specific_struct, zero_start)
     end
 end

function LAStopping(A      :: TA,
                    b      :: Tb;
                    x      :: Tb = zeros(eltype(Tb), size(A,2)),
                    sparse :: Bool = true,
                    kwargs...) where {TA <: Any, Tb <: AbstractVector}
 pb = sparse ? LLSModel(A,b) : LinearSystem(A,b)

 mcntrs = sparse ? _init_max_counters_NLS() : _init_max_counters_linear_operators()

 return LAStopping(pb, GenericState(x), max_cntrs = mcntrs; kwargs...)
end

function LAStopping(A      :: TA,
                    b      :: Tb,
                    state  :: S;
                    sparse :: Bool = true,
                    kwargs...) where {TA <: Any, Tb <: AbstractVector, S <: AbstractState}

 pb = sparse ? LLSModel(A,b) : LinearSystem(A,b)

 mcntrs = sparse ? _init_max_counters_NLS() : _init_max_counters_linear_operators()

 return LAStopping(pb, state, max_cntrs = mcntrs; kwargs...)
end

"""
Type: LACounters
"""
mutable struct  LACounters

    nprod   :: Int
    ntprod  :: Int
    nctprod :: Int
    sum     :: Int

    function LACounters(;nprod :: Int = 0, ntprod :: Int = 0, nctprod :: Int = 0, sum :: Int = 0)
        return new(nprod, ntprod, nctprod, sum)
    end
end

"""
\\_init\\_max\\_counters\\_linear\\_operators(): counters for LinearOperator

`_init_max_counters_linear_operators(;nprod :: Int = 20000, ntprod  :: Int = 20000, nctprod :: Int = 20000, sum :: Int = 20000*11)`
"""
function _init_max_counters_linear_operators(;nprod   :: Int = 20000,
                                              ntprod  :: Int = 20000,
                                              nctprod :: Int = 20000,
                                              sum     :: Int = 20000*11)

  cntrs = Dict([(:nprod,   nprod),   (:ntprod, ntprod),
                (:nctprod, nctprod), (:neval_sum,    sum)])

 return cntrs
end

"""
Type: LinearSystem
Minimal structure to store linear algebra problems
`LinearOperatorSystem(:: AbstractLinearOperator, :: AbstractVector)`

Note:
- Another option is to convert the LinearOperatorSystem as an LLSModel.
"""
mutable struct LinearSystem{TA <: Union{AbstractLinearOperator, AbstractMatrix}, Tb <: AbstractVector}
  A :: TA
  b :: Tb

  counters :: LACounters

  function LinearSystem(A :: TA, b :: Tb; counters :: LACounters = LACounters(), kwargs...) where {TA <: Union{AbstractLinearOperator, AbstractMatrix}, Tb <: AbstractVector}
      return new{TA,Tb}(A, b, counters)
  end
end

function LAStopping(A :: TA,
                    b :: Tb;
                    x :: Tb = zeros(eltype(Tb), size(A,2)),
                    kwargs...) where {TA <: AbstractLinearOperator, Tb <: AbstractVector}
 return LAStopping(A, b, GenericState(x), kwargs...)
end

function LAStopping(A :: TA,
                    b :: Tb,
                    state :: AbstractState;
                    kwargs...)  where {TA <: AbstractLinearOperator, Tb <: AbstractVector}
 return LAStopping(LinearSystem(A,b), state,
                   max_cntrs =  _init_max_counters_linear_operators(),
                   kwargs...)
end

 """
 \\_resources\\_check!: check if the optimization algorithm has exhausted the resources.
                        This is the Linear Algebra specialized version.

 Note:
 * function does _not_ keep track of the evals in the State
 * check :nprod, :ntprod, :nctprod in the LinearOperator entries
 """
 function _resources_check!(stp    :: LAStopping,
                            x      :: AbstractVector)

   cntrs = stp.pb.counters
   update!(stp.current_state, evals = cntrs)
   max_cntrs = stp.meta.max_cntrs

   # check all the entries in the counter
   max_f = false
   sum   = 0

   sum, max_f = _counters_loop(cntrs, max_cntrs, max_f, sum)

  # Maximum number of function and derivative(s) computation
  max_evals = sum > max_cntrs[:neval_sum]

  # global user limit diagnostic
  stp.meta.resources = max_evals || max_f

  return stp
 end

 function _counters_loop(cntrs :: LACounters, max_cntrs :: Dict, max_f :: Bool, sum :: Int)
     for f in [:nprod, :ntprod, :nctprod]
      max_f = max_f || (getfield(cntrs, f) > max_cntrs[f])
      sum  += getfield(cntrs, f)
     end
     return sum, max_f
 end

 function _counters_loop(cntrs :: NLSCounters, max_cntrs :: Dict, max_f :: Bool, sum :: Int)
     for f in fieldnames(NLSCounters)
      max_f = f != :counters ? (max_f || (getfield(cntrs, f) > max_cntrs[f])) : max_f
     end
     for f in fieldnames(Counters)
      max_f = max_f || (getfield(cntrs.counters, f) > max_cntrs[f])
     end
     return sum, max_f
 end

"""
linear\\_system\\_check: return ||Ax-b||_p

`linear_system_check(:: Any, :: AbstractState; pnorm :: Float64 = Inf, kwargs...)`

Note:
- Returns the p-norm of state.res
- state.res is filled in if nothing.
"""
function linear_system_check(pb    :: LinearSystem,
                             state :: AbstractState;
                             pnorm :: Float64 = Inf,
                             kwargs...)
 pb.counters.nprod += 1
 if state.res == nothing
  update!(state, res = pb.A * state.x - pb.b)
 end

 return norm(state.res, pnorm)
end

function linear_system_check(pb    :: LLSModel,
                             state :: AbstractState;
                             pnorm :: Float64 = Inf,
                             kwargs...)
 if state.res == nothing
  update!(state, res = residual(pb, state.x))
 end

 return norm(state.res, pnorm)
end

"""
linear\\_system\\_check: return ||A'Ax-A'b||_p

`linear_system_check(:: Any, :: AbstractState; pnorm :: Float64 = Inf, kwargs...)`

Note: pb must have A and b entries
"""
function normal_equation_check(pb    :: LinearSystem,
                               state :: AbstractState;
                               pnorm :: Float64 = Inf,
                               kwargs...)
 pb.counters.nprod  += 1
 pb.counters.ntprod += 1
 return norm(pb.A' * (pb.A * state.x) - pb.A' * pb.b, pnorm)
end

function normal_equation_check(pb    :: LLSModel,
                               state :: AbstractState;
                               pnorm :: Float64 = Inf,
                               kwargs...)
 nres = jtprod_residual(pb, state.x, residual(pb, state.x))
 return norm(nres, pnorm)
end
