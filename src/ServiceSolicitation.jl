module ServiceSolicitation

using ThreadingUtilities, VectorizationBase
using VectorizationBase: num_threads, cache_linesize
using StrideArraysCore: object_and_preserve
using Requires

export batch, num_threads


worker_size() = VectorizationBase.nextpow2(num_threads())
worker_type() = VectorizationBase.mask_type(worker_size())
worker_pointer_type() = Ptr{worker_type()}

const WORKERS = Ref(zero(UInt128))
const STATES = UInt8[]

worker_pointer() = Base.unsafe_convert(worker_pointer_type(), pointer_from_objref(WORKERS))

function reserved(id)
    p = Base.unsafe_convert(worker_pointer_type(), STATES)
    vload(p, VectorizationBase.lazymul(cache_linesize(), id))
end

function _request_threads(id::UInt32, num_requested::UInt32)
    reserved_threads = reserved(id)
    reserved_count = count_ones(reserved_threads)
    no_threads = zero(worker_type())
    # reserved_count ≥ num_requested && return reserved_threads, no_threads
    reserved_count ≥ num_requested && return UnsignedIteratorEarlyStop(reserved_threads, num_requested), no_threads
    # to get more, we xchng, setting all to `0`
    # then see which we need, and free those we aren't using.
    wp = worker_pointer()
    _all_threads = all_threads = ThreadingUtilities._atomic_xchg!(wp, no_threads)
    additional_threads = count_ones(all_threads)
    # num_requested === StaticInt{-1}() && return reserved_threads, all_threads
    num_requested === StaticInt{-1}() && return UnsignedIteratorEarlyStop(reserved_threads | all_threads), all_threads
    excess = additional_threads + reserved_count - num_requested
    # signed(excess) ≤ 0 && return reserved_threads, all_threads
    signed(excess) ≤ 0 && return UnsignedIteratorEarlyStop(reserved_threads | all_threads), all_threads
    # we need to return the `excess` to the pool.
    lz = leading_zeros(all_threads) % UInt32
    # i = 8
    while true
        # start by trying to trim off excess from lz
        lz += excess%UInt32
        m = (one(worker_type()) << (UInt32(worker_size()) - lz)) - one(worker_type())
        masked = (all_threads & m) ⊻ all_threads
        excess -= count_ones(masked)
        all_threads &= (~masked)
        # @show bitstring(masked), count_ones(masked), bitstring(unused_threads), excess, lz, bitstring(all_threads)
        excess == 0 && break
        # i -= 1
        # @assert i > 0
    end
    ThreadingUtilities._atomic_store!(wp, _all_threads & (~all_threads))
    return UnsignedIteratorEarlyStop(reserved_threads | all_threads, num_requested), all_threads
end
function request_threads(id, num_requested)
    _request_threads(id % UInt32, num_requested % UInt32)
end
reserved_threads(id) = UnsignedIteratorEarlyStop(reserved(id))
reserved_threads(id, count) = UnsignedIteratorEarlyStop(reserved(id), count % UInt32)


function free_threads!(freed_threads)
    ThreadingUtilities._atomic_or!(worker_pointer(), freed_threads)
    nothing
end

include("batch.jl")
include("unsignediterator.jl")

reset_workers!() = WORKERS[] = UInt128((1 << (num_threads() - 1)) - 1)
function __init__()
    reset_workers!()
    resize!(STATES, num_threads() * cache_linesize())
    # @require ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210" include("forwarddiff.jl")
end

end
