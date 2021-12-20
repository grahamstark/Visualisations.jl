include( "server_libs.jl")

const DEFAULT_PORT=8054
const DEFAULT_SERVER="http://localhost:$DEFAULT_PORT/"

port = DEFAULT_PORT
if length(ARGS) > 0
   port = parse(Int, ARGS[1])
end

serve( stbdemo, port)

while true # FIXME better way?
   @debug "new STB Server; main loop; server running on port $port"
   sleep( 60 )
end