struct BatchClosure{F, A}
    f::F
end

function (b::BatchClosure{F,A})(p::Ptr{UInt}) where {F,A}
    (offset, args) = ThreadingUtilities.load(p, A, 1)
    (offset, start) = ThreadingUtilities.load(p, UInt, offset)
    (offset, stop ) = ThreadingUtilities.load(p, UInt, offset)

    b.f(args, start+one(UInt), stop)
    nothing
end

@inline function batch_closure(f::F, args::A) where {F,A}
    bc = BatchClosure{F,A}(f)
    @cfunction($bc, Cvoid, (Ptr{UInt},))
end

@inline function setup_batch!(p::Ptr{UInt}, fptr::Ptr{Cvoid}, argtup, start::UInt, stop::UInt)
    offset = ThreadingUtilities.store!(p, fptr, 0)
    offset = ThreadingUtilities.store!(p, argtup, offset)
    offset = ThreadingUtilities.store!(p, start, offset)
    offset = ThreadingUtilities.store!(p, stop, offset)
    nothing
end
@inline function launch_batched_thread!(cfunc, tid, argtup, start, stop)
    p = ThreadingUtilities.taskpointer(tid)
    fptr = Base.unsafe_convert(Ptr{Cvoid}, cfunc)
    while true
        if ThreadingUtilities._atomic_cas_cmp!(p, ThreadingUtilities.SPIN, ThreadingUtilities.STUP)
            setup_batch!(p, fptr, argtup, start, stop)
            @assert ThreadingUtilities._atomic_cas_cmp!(p, ThreadingUtilities.STUP, ThreadingUtilities.TASK)
            return
        elseif ThreadingUtilities._atomic_cas_cmp!(p, ThreadingUtilities.WAIT, ThreadingUtilities.STUP)
            setup_batch!(p, fptr, argtup, start, stop)
            @assert ThreadingUtilities._atomic_cas_cmp!(p, ThreadingUtilities.STUP, ThreadingUtilities.LOCK)
            ThreadingUtilities.wake_thread!(tid % UInt)
            return
        end
        ThreadingUtilities.pause()
    end
end

@generated function batch(
    f!::F, args::Tuple{Vararg{Any,K}}, len, nbatches
) where {F,K}
    q = quote
        myid = Base.Threads.threadid()
        threads, torelease = request_threads(myid, nbatches - one(nbatches))
        _nthread = unsigned(length(threads))
        ulen = len % UInt
        if iszero(_nthread)
            f!(args, one(UInt), ulen)
            return
        end
        nbatch = _nthread + one(_nthread)
        nthread = _nthread % UInt32
        
        Nd = Base.udiv_int(ulen, nbatch % UInt)
        Nr = ulen - Nd * nbatch
        Ndp = Nd + one(Nd)
    end
    block = quote
        start = zero(UInt)
        i = 0x00000000
        tid = 0x00000000
        tm = mask(threads)
        while true
            VectorizationBase.assume(tm ≠ zero(tm))
            tz = trailing_zeros(tm) % UInt32
            i += 0x00000001
            tz += 0x00000001
            stop = start + ifelse(i < Nr, Ndp, Nd)
            tid += tz
            tm >>>= tz
            launch_batched_thread!(cfunc, tid, argtup, start, stop)
            start = stop
            i == nthread && break
        end
    end
    gcp = Expr(:gc_preserve, block, :cfunc)
    argt = Expr(:tuple)
    for k ∈ 1:K
        parg_k = Symbol(:parg_,k)
        garg_k = Symbol(:garg_,k)
        push!(q.args, Expr(:(=), Expr(:tuple, parg_k, garg_k), Expr(:call, :object_and_preserve, Expr(:ref, :args, k))))
        push!(argt.args, parg_k)
        push!(gcp.args, garg_k)
    end
    push!(q.args, :(argtup = $argt), :(cfunc = batch_closure(f!, argtup)), gcp, nothing)
    final = quote
        # f!(args, start, ulen)
        f!(argtup, start, ulen)
        tm = mask(threads)
        tid = 0x00000000
        while true
            VectorizationBase.assume(tm ≠ zero(tm))
            tz = trailing_zeros(tm) % UInt32
            tz += 0x00000001
            tm >>>= tz
            tid += tz
            ThreadingUtilities.__wait(tid)
            iszero(tm) && break
        end
        free_threads!(torelease)
        nothing
    end
    push!(q.args, final)
    q
end
function batch(
    f::F, args::Tuple{Vararg{Any,K}}, len, nbatches, reserve_per_worker
) where {F,K}
    threads = request_threads(id, nbatches * reserve_per_worker)
    
end
