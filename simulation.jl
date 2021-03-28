using Distributed

addprocs(8; exeflags="--project")

@everywhere begin
    using DelimitedFiles
    using ProgressMeter
    using ThreadsX
    using Base.Iterators

    using Random, Distributions
    using LinearAlgebra


    include("utils/stats.jl")
    include("utils/dgp.jl")

end

@everywhere function simulation(N, β₁, design)

    Y, X, U = dgpolsdesign$(design)(N, β₁)

    # Computing U-statistic and Δ₂
    Ustat = computeU(X, U, N)
    Δ₂₁, Δ₂₂ = computeΔ₂(X, U, N)

    # Computing OLS estimations
    X̃ = variablesreg(X, N)
    Ỹ = variablesreg(Y, N)
    β̂₁ = OLSestimator(Ỹ,X̃)
    varβ̂₁eff144 = OLSvariance(X̃, Δ₂₁, 144)
    varβ̂₁eff72 = OLSvariance(X̃, Δ₂₁, 72)
    varβ̂₁ineff144 = OLSvariance(X̃, Δ₂₂, 144)
    varβ̂₁ineff72 = OLSvariance(X̃, Δ₂₂, 72)

    return Δ₂₁, Δ₂₂, Ustat, β̂₁, varβ̂₁eff144, varβ̂₁eff72, varβ̂₁ineff144, varβ̂₁ineff72

end

β₁ = 1
N = 10
sims = 10000
design = 1

result = @time @showprogress pmap(1:sims) do sim
    simulation(N, β₁, design)
end

writedlm("results/outN$(N)sims$(sims)_design$(design).csv", result, ',')