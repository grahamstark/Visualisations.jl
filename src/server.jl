
serve(stbdemo, port)

include( "src/server_libs.jl")

while true # FIXME better way?
   @debug "new STB Server; main loop; server running on port $port"
   sleep( 60 )
end