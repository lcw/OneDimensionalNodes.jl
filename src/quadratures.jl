#=
The following code is modified from
https://github.com/billmclean/GaussQuadrature.jl with the original license:

> The MIT License (MIT)

> Copyright (c) 2013 billmclean

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:

> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.

> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
=#

# October 2013 by Bill McLean, School of Maths and Stats,
# The University of New South Wales.
#
# Based on earlier Fortran codes
#
# gaussq.f original version 20 Jan 1975 from Stanford
# gaussq.f modified 21 Dec by Eric Grosse
# gaussquad.f95 Nov 2005 by Bill Mclean
#
# This module provides functions to compute the abscissae x[j] and
# weights w[j] for the classical Gauss quadrature rules, including
# the Radau and Lobatto variants.  Thus, the sum
#
#           n
#           ∑  w[j] f(x[j])
#          j=1
#
# approximates
#
#           hi
#          ∫  f(x) w(x) dx
#          lo
#
# where the weight function w(x) and interval lo < x < hi are as shown
# in the table below.
#
# Name                      Interval     Weight Function
#
# Legendre                 -1 < x < 1          1
# Chebyshev (first kind)   -1 < x < 1     1 / sqrt(1-x²)
# Chebyshev (second kind)  -1 < x < 1       sqrt(1-x²)
# Jacobi                   -1 < x < 1     (1-x)ᵅ (1+x)ᵝ
# Laguerre                  0 < x < ∞     xᵅ exp(-x)
# Hermite                  -∞ < x < ∞      exp(-x²)
#
# In addition to these classical rules, the module generates Gauss rules
# for logarithmic weights of the form
#
#    w(x) = x^ρ log(1/x)   for 0 < x < 1.
#
# For the Jacobi and Laguerre rules we require α > -1 and
# β > -1, so that the weight function is integrable.  Likewise, for
# log weight we require ρ > -1.
#
# Use the endpoint argument to include one or both of the end points
# of the interval of integration as an abscissa in the quadrature
# rule, as follows.
#
# endpoint = NeitherEndPoint()   Default      lo < x[j] < hi, j = 1:n.
# endpoint = LeftEndPoint()      Left Radau   lo = x[1] < x[j] < hi, j = 2:n.
# endpoint = RightEndPoint()     Right Radau  lo < x[j] < x[n] = hi, j = 1:n-1.
# endpoint = BothEndPoint()      Lobatto      lo = x[1] < x[j] < x[n] = hi, j = 2:n-1.
#
#
# The code uses the Golub and Welsch algorithm, in which the abscissae
# x[j] are the eigenvalues of a symmetric tridiagonal matrix whose
# entries depend on the coefficients in the 3-term recurrence relation
# for the othonormal polynomials generated by the weighted inner product.
#
# References:
#
#   1.  Golub, G. H., and Welsch, J. H., Calculation of Gaussian
#       quadrature rules, Mathematics of Computation 23 (April,
#       1969), pp. 221-230.
#   2.  Golub, G. H., Some modified matrix eigenvalue problems,
#       Siam Review 15 (april, 1973), pp. 318-334 (section 7).
#   3.  Stroud and Secrest, Gaussian Quadrature Formulas, Prentice-
#       Hall, Englewood Cliffs, N.J., 1966.

# Enumeration type used to specify which endpoints of the integration
# interval should be included amongst the quadrature points: neither,
# left, right, or both.

abstract type EndPoint end
struct NeitherEndPoint <: EndPoint end
struct LeftEndPoint <: EndPoint end
struct RightEndPoint <: EndPoint end
struct BothEndPoint <: EndPoint end

"""
    x, w = legendregauss(T, n, endpoint::EndPoint=OneDimensionalNodes.NeitherEndPoint())

Returns points `x` and weights `w` for the `n`-point Gauss-Legendre rule
for the interval `-1 < x < 1` with weight function `w(x) = 1`.

Use `endpoint=LeftEndPoint()`, `RightEndPoint() ` or `BothEndPoints()` for the
left Radau, right Radau, or Lobatto rules, respectively.
"""
function legendregauss(::Type{T}, n::Integer, endpoint=NeitherEndPoint()) where {T}
    @assert n ≥ 1
    a, b = legendrecoefficients(T, n)
    return gaussrule(-one(T), one(T), a, b, endpoint)
end

"""
    x, w = legendregauss(n, endpoint::EndPoint=OneDimensionalNodes.NeitherEndPoint())

Convenience function with type `T = Float64`:
"""
legendregauss(n, endpoint::EndPoint=NeitherEndPoint()) = legendregauss(Float64, n, endpoint)

"""
    x, w = legendregausslobatto(T, n)

Returns points `x` and weights `w` for the `n`-point Legendre-Gauss-Lobatto rule
for the interval `-1 ≤ x ≤ 1` with weight function `w(x) = 1`.
"""
function legendregausslobatto(::Type{T}, n::Integer) where {T}
    return legendregauss(T, n, BothEndPoint())
end

"""
    x, w = legendregausslobatto(n)

Convenience function with type `T = Float64`:
"""
legendregausslobatto(n::Integer) = legendregausslobatto(Float64, n)

function legendrecoefficients(::Type{T}, n::Integer) where {T}
    a = zeros(T, n)
    b = zeros(T, n + 1)
    b[1] = sqrt(convert(T, 2))
    for k in 2:(n+1)
        b[k] = (k - 1) / sqrt(convert(T, (2k - 1) * (2k - 3)))
    end
    return a, b
end

"""
    x, w = gaussrule(lo, hi, a, b, endpoint, maxiterations=100)

Generates the points `x` and weights `w` for a Gauss rule with weight
function `w(x)` on the interval `lo < x < hi`.

The arrays `a` and `b` hold the coefficients (as given, for instance, by
`legendrecoefficients`) in the three-term recurrence relation for the monic
orthogonal polynomials `p(0,x)`, `p(1,x)`, `p(2,x)`, ... , that is,

    p(k, x) = (x-a[k]) p(k-1, x) - b[k]² p(k-2, x),    k ≥ 1,

where `p(0, x) = 1` and, by convention, `p(-1, x) = 0` with

              hi
    b[1]^2 = ∫  w(x) dx.
             lo

Thus, `p(k, x) = xᵏ + lower degree terms` and

     hi
    ∫  p(j, x) p(k, x) w(x) dx = 0 if j ≠ k.
    lo
"""
function gaussrule(lo, hi, a, b, endpoint::EndPoint, maxiterations=100)
    T = promote_type(typeof(lo), typeof(hi), eltype(a), eltype(b))
    n = length(a)
    @assert length(b) == n + 1
    if endpoint isa LeftEndPoint
        if n == 1
            a[1] = lo
        else
            a[n] = tridiagonalshiftsolve(n, lo, a, b) * b[n]^2 + lo
        end
    elseif endpoint isa RightEndPoint
        if n == 1
            a[1] = hi
        else
            a[n] = tridiagonalshiftsolve(n, hi, a, b) * b[n]^2 + hi
        end
    elseif endpoint isa BothEndPoint
        if n == 1
            error("Must have at least two points for both ends.")
        end
        g = tridiagonalshiftsolve(n, lo, a, b)
        t1 = (hi - lo) / (g - tridiagonalshiftsolve(n, hi, a, b))
        b[n] = sqrt(t1)
        a[n] = lo + g * t1
    end
    w = zero(a)
    tridiagonaleigenproblem!(a, b, w, maxiterations)
    for i in 1:n
        w[i] = (b[1] * w[i])^2
    end
    idx = sortperm(a)
    # Ensure end point values are exact.
    if endpoint isa LeftEndPoint || endpoint isa BothEndPoint
        a[idx[1]] = lo
    end
    if endpoint isa RightEndPoint || endpoint isa BothEndPoint
        a[idx[n]] = hi
    end
    return a[idx], w[idx]
end

function tridiagonalshiftsolve(n, shift, a, b)
    #
    # Perform elimination to find the nth component s = delta[n]
    # of the solution to the nxn linear system
    #
    #     ( J_n - shift I_n ) delta = e_n,
    #
    # where J_n is the symmetric tridiagonal matrix with diagonal
    # entries a[i] and off-diagonal entries b[i], and e_n is the nth
    # standard basis vector.
    #
    t = a[1] - shift
    for i in 2:(n-1)
        t = a[i] - shift - b[i]^2 / t
    end
    return one(t) / t
end

function tridiagonaleigenproblem!(d, e, z, maxiterations)
    #
    # Finds the eigenvalues and first components of the normalised
    # eigenvectors of a symmetric tridiagonal matrix by the implicit
    # QL method.
    #
    # d[i]   On entry, holds the ith diagonal entry of the matrix.
    #        On exit, holds the ith eigenvalue.
    #
    # e[i]   On entry, holds the [i,i-1] entry of the matrix for
    #        i = 2, 3, ..., n.  (The value of e[1] is not used.)
    #        On exit, e is overwritten.
    #
    # z[i]   On exit, holds the first component of the ith normalised
    #        eigenvector associated with d[i].
    #
    # maxiterations The maximum number of QL iterations.
    #
    # Martin and Wilkinson, Numer. Math. 12: 377-383 (1968).
    # Dubrulle, Numer. Math. 15: 450 (1970).
    # Handbook for Automatic Computation, Vol ii, Linear Algebra,
    #        pp. 241-248, 1971.
    #
    # This is a modified version of the Eispack routine imtql2.
    #
    T = promote_type(eltype(d), eltype(e), eltype(z))
    n = length(z)
    z[1] = one(T)
    z[2:n] .= zero(T)
    e[n+1] = zero(T)

    if n == 1 # Nothing to do for a 1x1 matrix.
        return
    end
    for l in 1:n
        for j in 1:maxiterations
            # Look for small off-diagonal elements.
            m = n
            for i in l:(n-1)
                if abs(e[i+1]) <= eps(T) * (abs(d[i]) + abs(d[i+1]))
                    m = i
                    break
                end
            end
            p = d[l]
            if m == l
                continue
            end
            if j == maxiterations
                msg = string("No convergence after ", j, " iterations",
                    " (try increasing maxiterations)")
                error(msg)
            end
            # Form shift
            g = (d[l+1] - p) / (2 * e[l+1])
            r = hypot(g, one(T))
            g = d[m] - p + e[l+1] / (g + copysign(r, g))
            s = one(T)
            c = one(T)
            p = zero(T)
            for i in (m-1):-1:l
                f = s * e[i+1]
                b = c * e[i+1]
                if abs(f) < abs(g)
                    s = f / g
                    r = hypot(s, one(T))
                    e[i+2] = g * r
                    c = one(T) / r
                    s *= c
                else
                    c = g / f
                    r = hypot(c, one(T))
                    e[i+2] = f * r
                    s = one(T) / r
                    c *= s
                end
                g = d[i+1] - p
                r = (d[i] - g) * s + 2 * c * b
                p = s * r
                d[i+1] = g + p
                g = c * r - b
                # Form first component of vector.
                f = z[i+1]
                z[i+1] = s * z[i] + c * f
                z[i] = c * z[i] - s * f
            end
            d[l] -= p
            e[l+1] = g
            e[m+1] = zero(T)
        end
    end
    return
end
