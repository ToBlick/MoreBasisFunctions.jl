#######################
# The Lagrange basis
#######################

using Polynomials: Poly, polyint
using BasisFunctions: ChebyshevInterval, PolynomialBasis
using BasisFunctions: hasderivative, hasantiderivative, support

const LagrangeInterval = ChebyshevInterval
const LagrangeIndex = NativeIndex{:lagrange}

"""
A basis of the Lagrange polynomials `l_i(x) = ∏_(j,i≠j) (x - ξ^j) / (ξ^i - ξ^j)`
on the interval [-1,+1].
"""
struct Lagrange{T} <: PolynomialBasis{T,T}
    n :: Int
    nodes :: ScatteredGrid{T}

    denom::Vector{T}    # denominator of Lagrange polynomials
    diffs::Matrix{T}    # inverse of differences between nodes
    vdminv::Matrix{T}   # inverse Vandermonde matrix

    function Lagrange{T}(nodes) where {T}
        local p::T

        local ξ = nodes.points
        local n = length(ξ)

        @assert minimum(ξ) ≥ leftendpoint(support(nodes))
        @assert maximum(ξ) ≤ rightendpoint(support(nodes))

        denom = ones(n)
        diffs = zeros(n,n)

        for i in 1:length(ξ)
            p = 1
            for j in 1:length(ξ)
                diffs[i,j] = 1 / (ξ[i] - ξ[j])
                if i ≠ j
                    denom[i] *= diffs[i,j]
                end
            end
        end

        new(n, nodes, denom, diffs, vandermonde_matrix_inverse(ξ))
    end
end

function Lagrange(nodes::ScatteredGrid{T}) where {T}
    Lagrange{T}(nodes)
end

function Lagrange(ξ::Vector{T}) where {T}
    Lagrange(ScatteredGrid(ξ, LagrangeInterval()))
end

# Convenience constructor: map the Lagrange basis to the interval [a,b]
Lagrange(x, a::Number, b::Number) = rescale(Lagrange(x), a, b)


nodes(b::Lagrange)  = b.nodes.points
nnodes(b::Lagrange) = b.n
degree(b::Lagrange) = b.n-1

BasisFunctions.native_index(b::Lagrange, idxn) = LagrangeIndex(idxn)
BasisFunctions.hasderivative(b::Lagrange) = true
BasisFunctions.hasantiderivative(b::Lagrange) = true
BasisFunctions.support(b::Lagrange) = support(b.nodes)

Base.size(b::Lagrange) = b.n


function BasisFunctions.unsafe_eval_element(b::Lagrange{T}, idx::LagrangeIndex, x::T) where {T}
    local y::T = 1
    local ξ = nodes(b)
    for i in 1:length(ξ)
        i ≠ idx ? y *= x - ξ[i] : nothing
    end
    y * b.denom[value(idx)]
end


function BasisFunctions.unsafe_eval_element_derivative(b::Lagrange{T}, idx::LagrangeIndex, x::T) where {T}
    local y::T = 0
    local z::T
    local ξ = nodes(b)
    local d = b.diffs

    for l in 1:nnodes(b)
        if l ≠ idx
            z = d[idx,l]
            for i in 1:nnodes(b)
                i ≠ idx && i ≠ l ? z *= (x - ξ[i]) * d[idx,i] : nothing
            end
            y += z
        end
    end
    y
end


function unsafe_eval_element_antiderivative(b::Lagrange{T}, idx::LagrangeIndex, x::T) where {T}
    local y = zero(nodes(b))
    y[value(idx)] = 1
    lint = polyint(Poly(b.vdminv*y))
    return lint(x) - lint(leftendpoint(support(b)))
end


similar(b::Lagrange, ::Type{T}, nodes::ScatteredGrid{T}) where {T} = Lagrange{T}(nodes)
