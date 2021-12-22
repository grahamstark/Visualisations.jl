# 
# using Mux

include( "server_libs.jl")


const DEFAULT_PORT=8054
const DEFAULT_SERVER="http://localhost:$DEFAULT_PORT/"

port = DEFAULT_PORT
if length(ARGS) > 0
   port = parse(Int, ARGS[1])
end

# the wait() bit here should allow 'clean breaks' may not be needed
# in a live server.
# see note in: https://github.com/JuliaWeb/Mux.jl/blob/master/src/server.jl
# this doesn't clear the port on shutdown
# use: fuser 8054/tcp to kill everything
# see: https://stackoverflow.com/questions/750604/freeing-up-a-tcp-ip-port
# wait(serve( stbdemo, port))
host = "0.0.0.0"
HTTP.serve(Mux.http_handler(stbdemo), host, port )

#=
while true # FIXME better way?
   @debug "new STB Server; main loop; server running on port $port"
   sleep( 60 )
end
=# 