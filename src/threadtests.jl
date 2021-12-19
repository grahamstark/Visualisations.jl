using UUIDs,Base.Threads,Observables
d = Dict()

function g(p,uuid)
    sleep(1)
    for i in 1:30
      if i % 1 == 0
        s = 0.0
        for j in 1:100_000_000
            s += rand()
        end
        p[]=T(uuid,(i,s))       
       end
   end
end

function ad()
    o = Observable(T(0,0))
    on(o) do p
        d[p.a] = p.b
    end
    g(o,uuid)
end

uuid = UUIDs.uuid4()
@async ad(uuid)    

function aad()
    uuid = UUIDs.uuid4()
    t = @async ad()    
    (t, uuid)
end

#-- async using channels
using UUIDs,Base.Threads,Observables

struct T
    a 
    b 
end

progress = Dict()
data = Dict()

observer = Observable(T(0,0))
on(observer) do p
    progress[p.a] = p.b
end

inqueue = Channel{T}(32);
outqueue = Channel{T}(32);

function calc()
    global observer
    while true
        job = take!(inqueue)
        r = 0.0
        for i in 1:job.b
            r += rand()
            if i % 100 == 0
                observer[]= T(job.a,i) 
            end
        end
        put!( outqueue, T( job.a, r ))
    end
end

function submitjob()
    uuid = UUIDs.uuid4()
    put!( inqueue, T(uuid, rand(1:1_000_000)))
    return uuid
end

function makejobs(n)
    for i in 1:n 
        put!( inqueue, T(UUIDs.uuid4(), rand(1:1_000_000)))
    end
end

# i in 1:4 # start 4 tasks to process requests in parallel
#    errormonitor(@async calc())
# end

function clearjobs(n)
     while true
        res = take!( outqueue )
        data[res.a] = res
        print( "from clearjobs ")
        println( res )
    end
end

n = 32
function start_handlers(n)
    for i in 1:n # start 4 tasks to process requests in parallel
        errormonitor(@async calc())
    end

    errormonitor(@async clearjobs(n))
end