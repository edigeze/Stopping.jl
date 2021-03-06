###############################################################################
#
# The Stopping structure eases the implementation of algorithms and the
# stopping criterion.
#
# The following examples illustrate a specialized Stopping for the
# LinearOperators type.
# https://github.com/JuliaSmoothOptimizers/LinearOperators.jl
#
using LinearAlgebra, SparseArrays, LinearOperators #v.1.0.1

##############################################################
#TEST

n = 5
A = rand(n,n)
xref = 100 * rand(n)
x0 = zeros(n)
b    = A * xref
sA  = sparse(A)
opA = LinearOperator(A)

mLO = LinearSystem(A, b)
sLO = LLSModel(sA, b)
opLO = LinearSystem(opA, b)
mLOstp = LAStopping(mLO, GenericState(x0), max_cntrs =  Stopping._init_max_counters_linear_operators())
sLOstp = LAStopping(sLO, GenericState(x0))
short_stop = LAStopping(A,b, sparse = true) #note that sparse is true by default
maxcn = Stopping._init_max_counters_linear_operators(nprod = 1)
opLOstp = LAStopping(opLO, GenericState(x0), max_cntrs = maxcn)

@test typeof(mLOstp.pb.counters) <: LACounters
@test typeof(sLOstp.pb.counters) <: NLSCounters
@test typeof(opLOstp.pb.counters) <: LACounters
@test typeof(short_stop.pb.counters) <: NLSCounters
@test typeof(short_stop.pb) <: LLSModel

@test start!(mLOstp) == false
@test start!(sLOstp) == false
@test start!(opLOstp) == false

update_and_stop!(mLOstp, x = xref, res = nothing)
@test status(mLOstp) == :Optimal
@test mLOstp.meta.resources == false
update_and_stop!(sLOstp, x = xref, res = nothing)
@test status(sLOstp) == :Optimal
@test sLOstp.meta.resources == false
update_and_stop!(opLOstp, x = xref, res = nothing)
@test status(opLOstp) == :Optimal
@test opLOstp.meta.resources == true

include("_additional_linear_operator_algebra.jl")

"""
Randomized block Kaczmarz
"""
function RandomizedBlockKaczmarz(stp :: AbstractStopping; kwargs...)

    A,b = stp.pb.A, stp.pb.b
    x0  = stp.current_state.x

    m,n = size(A)
    xk  = x0

    OK = start!(stp)

    while !OK

     i  = Int(floor(rand() * m)+1) #rand a number between 1 and m
     Ai = A[i,:]
     xk  = Ai == 0 ? x0 : x0 - (dot(Ai,x0)-b[i])/dot(Ai,Ai) * Ai
     #xk  = Ai == 0 ? x0 : x0 - (Ai' * x0-b[i])/(Ai' * Ai) * Ai

     OK = update_and_stop!(stp, x = xk, res = nothing)
     x0  = xk

    end

 return stp
end

m, n = 400, 200 #size of A: m x n
A    = 100 * rand(m, n) #It's a dense matrix :)
xref = 100 * rand(n)
b    = A * xref

#Our initial guess
x0 = zeros(n)

la_stop = LAStopping(A, b, GenericState(x0), max_iter = 150000, rtol = 1e-6, max_cntrs = Stopping._init_max_counters_NLS(residual = 150000))
#Be careful using GenericState(x0) would not work here without forcing convert = true
#in the update function. As the iterate will be a SparseVector to the contrary of initial guess.
#Tangi: maybe start! should send a Warning for such problem !?
sa_stop = LAStopping(sparse(A), b, GenericState(sparse(x0)), max_iter = 150000, rtol = 1e-6)
op_stop = LAStopping(LinearSystem(LinearOperator(A), b), GenericState(x0), max_iter = 150000, rtol = 1e-6, max_cntrs =  Stopping._init_max_counters_linear_operators(nprod = 150000))
opbis_stop = LAStopping(LinearOperator(A), b)

try
 @time RandomizedBlockKaczmarz(la_stop)
 @test status(la_stop) == :Optimal
 @time RandomizedBlockKaczmarz(sa_stop)
 @test status(sa_stop) == :Optimal
 @time RandomizedBlockKaczmarz(op_stop)
 @test status(op_stop) == :Optimal
catch
    @warn "If LSSModel.A does not exist consider [la_stop.pb.Avals[i,j] for (i) in la_stop.pb.Arows, j in la_stop.pb.Acols]"
    #https://github.com/JuliaSmoothOptimizers/NLPModels.jl/blob/master/src/lls_model.jl
end

update!(la_stop.current_state, x = xref)
@test normal_equation_check(la_stop.pb, la_stop.current_state) <= la_stop.meta.atol
update!(op_stop.current_state, x = xref)
@test normal_equation_check(op_stop.pb, op_stop.current_state) <= la_stop.meta.atol
