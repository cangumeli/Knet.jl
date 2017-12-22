# TODO: test bidirectional rnns

include("header.jl")

if gpu() >= 0

using Knet: rnntest

eq(a,b)=all(map((x,y)->(x==y==nothing || isapprox(x,y)),a,b))
gchk(a...)=gradcheck(a...; rtol=0.01)
rnn1(p,r,b=nothing)=rnnforw(r,p...;batchSizes=b)[1]
D,X,H,B,T = Float64,32,32,16,10 # Keep X==H to test skipInput

r=w=x1=x2=x3=hx1=cx1=hx2=cx2=hx3=cx3=nothing
rcpu=wcpu=x1cpu=x2cpu=x3cpu=hx1cpu=cx1cpu=hx2cpu=cx2cpu=hx3cpu=cx3cpu=nothing
@testset "rnn" begin
    for M=(:relu,:tanh,:lstm,:gru), L=1:2, I=(:false,:true), BI=(:false,:true)
        (r,w) = rnninit(X, H; dataType=D, rnnType=M, numLayers=L, skipInput=I, bidirectional=BI, binit=xavier) # binit=zeros does not pass gchk
        (rcpu,wcpu) = rnninit(X, H; dataType=D, rnnType=M, numLayers=L, skipInput=I, bidirectional=BI, binit=xavier, usegpu=false)
        @test eltype(wcpu) == eltype(w)
        @test size(wcpu) == size(w)
        wcpu = Array(w)
        HL = BI?2L:L

        # rnntest tests cudnn vs my implementation on gpu
        # rnnforw(rcpu...) compares cpu vs gpu
        x1cpu = randn(D,X); x1 = ka(x1cpu)
        hx1cpu = randn(D,H,1,HL); hx1 = ka(hx1cpu)
        cx1cpu = randn(D,H,1,HL); cx1 = ka(cx1cpu)
        @test eq(rnnforw(r,w,x1),rnntest(r,w,x1))
        @test eq(rnnforw(r,w,x1),rnnforw(rcpu,wcpu,x1cpu))
        @test eq(rnnforw(r,w,x1,hx1,cx1),rnntest(r,w,x1,hx1,cx1))
        @test eq(rnnforw(r,w,x1,hx1,cx1),rnnforw(rcpu,wcpu,x1cpu,hx1cpu,cx1cpu))
        @test eq(rnnforw(r,w,x1,hx1,cx1;batchSizes=[1]),rnntest(r,w,x1,hx1,cx1)) 
        @test gchk(rnn1,[w,x1,hx1,cx1],r)
        @test gchk(rnn1,[w,x1,hx1,cx1],r,[1])
        @test gchk(rnn1,[wcpu,x1cpu,hx1cpu,cx1cpu],rcpu)
        @test gchk(rnn1,[wcpu,x1cpu,hx1cpu,cx1cpu],rcpu,[1])

        x2cpu =  randn(D,X,B); x2 = ka(x2cpu)
        hx2cpu = randn(D,H,B,HL); hx2 = ka(hx2cpu)
        cx2cpu = randn(D,H,B,HL); cx2 = ka(cx2cpu)
        @test eq(rnnforw(r,w,x2),rnntest(r,w,x2))
        @test eq(rnnforw(r,w,x2),rnnforw(rcpu,wcpu,x2cpu))
        @test eq(rnnforw(r,w,x2,hx2,cx2),rnntest(r,w,x2,hx2,cx2))
        @test eq(rnnforw(r,w,x2,hx2,cx2),rnnforw(rcpu,wcpu,x2cpu,hx2cpu,cx2cpu))
        @test eq(rnnforw(r,w,x2,hx2,cx2;batchSizes=[B]),rnntest(r,w,x2,hx2,cx2))
        @test gchk(rnn1,[w,x2,hx2,cx2],r)
        @test gchk(rnn1,[wcpu,x2cpu,hx2cpu,cx2cpu],rcpu)
        for b in ([16],[8,8],[10,4,2])
            hx2 = ka(randn(D,H,b[1],HL))
            cx2 = ka(randn(D,H,b[1],HL))
            hx2cpu = Array(hx2)
            cx2cpu = Array(cx2)
            @test gchk(rnn1,[w,x2,hx2,cx2],r,b)
            @test gchk(rnn1,[wcpu,x2cpu,hx2cpu,cx2cpu],rcpu,b)
            #end
        end
        x3cpu = randn(D,X,B,T); x3 = ka(x3cpu)
        hx3cpu = randn(D,H,B,HL); hx3 = ka(hx3cpu)
        cx3cpu = randn(D,H,B,HL); cx3 = ka(cx3cpu)
        @test eq(rnnforw(r,w,x3),rnntest(r,w,x3))
        @test eq(rnnforw(r,w,x3),rnnforw(rcpu,wcpu,x3cpu))
        @test eq(rnnforw(r,w,x3,hx3,cx3),rnntest(r,w,x3,hx3,cx3))
        @test eq(rnnforw(r,w,x3,hx3,cx3),rnnforw(rcpu,wcpu,x3cpu,hx3cpu,cx3cpu))
        @test eq(rnnforw(r,w,x3,hx3,cx3;batchSizes=[B for t=1:T]),rnntest(r,w,x3,hx3,cx3))
        @test gchk(rnn1,[w,x3,hx3,cx3],r)
        @test gchk(rnn1,[wcpu,x3cpu,hx3cpu,cx3cpu],rcpu)
        for b in ([160],[80,80],[100,40,20])
            hx3 = ka(randn(D,H,b[1],HL))
            cx3 = ka(randn(D,H,b[1],HL))
            hx3cpu = Array(hx3)
            cx3cpu = Array(cx3)
            @test gchk(rnn1,[w,x3,hx3,cx3],r,b)
            @test gchk(rnn1,[wcpu,x3cpu,hx3cpu,cx3cpu],rcpu,b)
        end
        
        # rnnparam, rnnparams
        for m in (1,2)
            for l in 1:L
                for i in 1:(M==:lstm ? 8 : M==:gru ? 6 : 2)
                    @test rnnparam(r,w,l,i,m) == rnnparam(r,wcpu,l,i,m)
                end
            end
        end
        @test all(map(==, rnnparams(r,w), rnnparams(r,wcpu)))
    end # for
end # @testset

    #=@testset "batchSizes" begin
        x = KnetArray(rand(10, 5+5+4+3))
        xcpu = Array(x)
        for M=(:relu,:tanh,:lstm,:gru), L=1:2, I=(:false,:true), BI=(:false#=:true=#)
            
            r,w = rnninit(10, 10;
                          dataType=Float64,
                          rnnType=M, numLayers=L,
                          skipInput=I, bidirectional=BI)
            rcpu, _ = rnninit(10, 10;
                              dataType=Float64,
                              rnnType=M, numLayers=L, skipInput=I,
                              bidirectional=BI, usegpu=false)
            wcpu = Array(w)
                for bs in ([17], [10,4,3], [5,5,4,3])
                    @testset "$M $L $I $BI $bs" begin   
                        @test eq(rnnforw(r, w, x; hy=true, cy=true, batchSizes=bs),
                                 rnnforw(r, wcpu, xcpu; hy=true, cy=true, batchSizes=bs))
                    end
                end
        end=#
    #end
    
end # if gpu() >= 0

nothing

