using OneDimensionalNodes
using Aqua
using FastGaussQuadrature
using Test

Aqua.test_all(OneDimensionalNodes)

include("operators.jl")
include("quadratures.jl")
