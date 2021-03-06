"""
Function that takes double differencing
"""
function Δ(M, i, j, k, l)
    @inbounds M[i, j] - M[i, k] - M[l, j] + M[l, k]
end

"""
Function that computes the score
"""
function s(U, X, i, j, k, l)
    return Δ(U, i, j, k, l) * Δ(X, i, j, k, l)
end

"""
Computes the summand for the first estimator of Δ₂
"""
function scombs(X, U, i, j, k, l)
    summand = @inbounds (
        Δ(X, i, j, k, l) * U[i,j] +
        Δ(X, i, k, j, l) * (- U[i,j]) +
        Δ(X, k, j, l, i) * (- U[i,j]) +
        Δ(X, l, k, j, i) * U[i,j] +
        Δ(X, k, l, j, i) * U[i,j] +
        Δ(X, l, j, k, i) * (- U[i,j]) +
        Δ(X, i, j, l, k) * U[i,j] +
        Δ(X, i, l, j, k) * (- U[i,j]) 
    )

    return summand / 24
end

"""
Computes the summand for the second estimator of Δ₂
"""
function scombsinefficient(X, U, i, j, k, l)
    summand = 0.
    tup = (i, j, k, l)
    
    @inbounds for a in tup, b in tup
        (a - b) == 0 && continue
        for c in tup, d in tup
            (c - a) * (c - b) == 0 && continue
            (d - c) * (d - b) * (d - a) == 0 && continue
            summand += s(U, X, a, b, c, d) 
        end
    end

    return summand / 24

end


@inline function computeU(X::Matrix, U::Matrix, N::Int64)

    Nσ = N * (N - 1) * (N - 2) * (N - 3)

    u = 0.

    @inbounds for i in 1:N, j in 1:N
        (i - j) == 0 && continue
        for k in 1:N, l in 1:N
            (k - i) * (k - j) == 0 && continue
            (l - k) * (l - j) * (l - i) == 0 && continue
            u += s(U, X, i, j, k, l)
        end
    end

    return u / Nσ

end



@inline function computeΔ₂(X::Matrix, U::Matrix, N::Int64)

    Ndyads = N * (N - 1)
    s̄₁ = 0.
    s̄₂ = 0.

    # Fixing a dyad i,j
    ThreadsX.foreach(product(1:N, 1:N)) do (i, j)
        (i - j) == 0 && return

        sdyad₁ = 0.
        sdyad₂ = 0.
        Ncombs = binomial(N - 2, 2)

        # Obtaining the conditional expectations over this dyad
        @inbounds for l in 1:N, k in l:N
            (l - i) * (l - j) == 0 && continue
            (l - k) * (k - i) * (k - j) == 0 && continue

            sdyad₁ += scombs(X, U, i, j, k, l)
            sdyad₂ += scombsinefficient(X, U, i, j, k, l) 
        end

        s̄₁ += (sdyad₁ / Ncombs)^2
        s̄₂ += (sdyad₂ / Ncombs)^2
    
    end

    # Taking the average over dyads for both estimators
    Δ₂₁ = s̄₁ / Ndyads
    Δ₂₂ = s̄₂ / Ndyads 

    return Δ₂₁, Δ₂₂

end


""" 
Function that computes X\tilde or Y\tilde for OLS regression
"""
function variablesreg(X::Matrix, N::Int64)
    X̃ = zeros(N * (N-1) * (N-2) * (N-3))

    counter = 1
    # Getting the permutations for constructing the variable
    @inbounds for i in 1:N, j in 1:N # Did not include the threadsX because the order matters
        (i - j) == 0 && continue

        @inbounds for l in 1:N, k in 1:N
            (l - i) * (l - j) == 0 && continue
            (l - k) * (k - i) * (k - j) == 0 && continue

            X̃[counter] = Δ(X, i, j, k, l)
            counter += 1
        end
    end

    return X̃

end

"""
Function that computes the OLS estimator and its variance from standard OLS
"""
function OLSestimator(Y,X)
    estimate = inv(X'*X)*(X'*Y)
    return estimate
end

"""
Function that computes the variance obtained with U-statistics
"""

function OLSvariance(X, Δ₂, F)
    Mₓₓ = (1/(N * (N-1) * (N-2) * (N-3))) * X' * X
    variance = (1/(N * (N-1))) * inv(Mₓₓ) * F * Δ₂ * inv(Mₓₓ)

    return variance
end
