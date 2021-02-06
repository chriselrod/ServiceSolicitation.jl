module ServiceSolicitation

using ThreadingUtilities, VectorizationBase
using VectorizationBase: num_threads, cache_linesize
using StrideArraysCore: object_and_preserve
using Requires

export batch, num_threads


include("request.jl")
include("batch.jl")
include("unsignediterator.jl")

reset_workers!() = WORKERS[] = UInt128((1 << (num_threads() - 1)) - 1)
function __init__()
    reset_workers!()
    resize!(STATES, num_threads() * cache_linesize())
    STATES .= 0x00
    # @require ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210" include("forwarddiff.jl")
end

end
