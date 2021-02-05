using ServiceSolicitation
# using Aqua
using Test

@testset "ServiceSolicitation.jl" begin
    # Aqua.test_all(ServiceSolicitation)
    
    function rangemap!(f::F, allargs, start, stop) where {F}
        dest = first(allargs)
        args = Base.tail(allargs)
        @inbounds @simd for i ∈ start:stop
            dest[i] = f(getindex.(args, i)...)
        end
        nothing
    end

    function tmap!(f::F, args::Vararg{AbstractArray,K}) where {K,F}
        dest = first(args)
        N = length(dest)
        mapfun! = (allargs, start, stop) -> rangemap!(f, allargs, start, stop)
        batch(mapfun!, args, N, num_threads())
        dest
    end

    x = rand(1024); y = rand(1024);
    z = similar(x);
    @test tmap!(+, z, x, y) ≈ x .+ y
end
