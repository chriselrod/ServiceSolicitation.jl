
struct UnsignedIterator{U}
    u::U
end

Base.IteratorSize(::Type{<:UnsignedIterator}) = Base.HasShape{1}()
Base.IteratorEltype(::Type{<:UnsignedIterator}) = Base.HasEltype()

Base.eltype(::UnsignedIterator) = UInt32
Base.length(u::UnsignedIterator) = count_ones(u.u)
Base.size(u::UnsignedIterator) = (count_ones(u.u),)

# @inline function Base.iterate(u::UnsignedIterator, uu = u.u)
#     tz = trailing_zeros(uu) % UInt32
#     # tz ≥ 0x00000020 && return nothing
#     tz > 0x0000001f && return nothing
#     uu ⊻= (0x00000001 << tz)
#     tz, uu
# end
@inline function Base.iterate(u::UnsignedIterator, (i,uu) = (0x00000000,u.u))
    tz = trailing_zeros(uu) % UInt32
    tz == 0x00000020 && return nothing
    i += tz
    tz += 0x00000001
    uu >>>= tz
    (i, (i+0x00000001,uu))
end


struct UnsignedIteratorEarlyStop{U}
    u::U
    i::UInt32
end
UnsignedIteratorEarlyStop(u) = UnsignedIteratorEarlyStop(u, count_ones(u) % UInt32)
UnsignedIteratorEarlyStop(u, i) = UnsignedIteratorEarlyStop(u, i % UInt32)

mask(u::UnsignedIteratorEarlyStop) = getfield(u, :u)
Base.IteratorSize(::Type{<:UnsignedIteratorEarlyStop}) = Base.HasShape{1}()
Base.IteratorEltype(::Type{<:UnsignedIteratorEarlyStop}) = Base.HasEltype()

Base.eltype(::UnsignedIteratorEarlyStop) = Tuple{UInt32,UInt32}
Base.length(u::UnsignedIteratorEarlyStop) = getfield(u, :i)
Base.size(u::UnsignedIteratorEarlyStop) = (getfield(u, :i),)

# @inline function Base.iterate(u::UnsignedIteratorEarlyStop, (i,j,uu) = (0x00000000,u.i,u.u))
@inline function Base.iterate(u::UnsignedIteratorEarlyStop, (i,j,uu) = (0x00000000,0x00000000,u.u))
    # VectorizationBase.assume(u.i ≤ 0x00000020)
    # VectorizationBase.assume(j ≤ count_ones(uu))
    # iszero(j) && return nothing
    j == u.i && return nothing
    VectorizationBase.assume(uu ≠ zero(uu))
    j += 0x00000001
    tz = trailing_zeros(uu) % UInt32
    tz += 0x00000001
    i += tz
    uu >>>= tz
    ((j,i), (i,j,uu))
end
function Base.show(io::IO, u::UnsignedIteratorEarlyStop)
    l = length(u)
    s = Vector{Int32}(undef, l) .= last.(u)
    print("Thread ($l) Iterator: U", s)
end

# @inline function Base.iterate(u::UnsignedIteratorEarlyStop, (i,uu) = (0xffffffff,u.u))
#     tz = trailing_zeros(uu) % UInt32
#     tz == 0x00000020 && return nothing
#     tz += 0x00000001
#     i += tz
#     uu >>>= tz
#     (i, (i,uu))
# end

