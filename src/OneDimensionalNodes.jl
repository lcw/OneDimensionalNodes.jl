module OneDimensionalNodes

using PrecompileTools
 
export spectralderivative, spectralinterpolation, legendregauss,
    legendregausslobatto

include("operators.jl")
include("quadratures.jl")

@setup_workload begin
    @compile_workload begin
        for T in (Float32, Float64, BigFloat)
            r, w = legendregausslobatto(T, 7)
            x = LinRange{T}(-1, 1, 101)
            D = spectralderivative(r)
            P = spectralinterpolation(r, x)

            x, w = legendregauss(T, 5, OneDimensionalNodes.NeitherEndPoint())
            x, w = legendregauss(T, 5, OneDimensionalNodes.LeftEndPoint())
            x, w = legendregauss(T, 5, OneDimensionalNodes.RightEndPoint())
            x, w = legendregauss(T, 5, OneDimensionalNodes.BothEndPoint())
        end

        x, w = legendregauss(5)
        x, w = legendregausslobatto(6)
    end
end

end # module
