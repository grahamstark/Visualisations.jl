#
# see: https://github.com/JuliaWeb/Mux.jl
# and:
#
using Mux
import Mux.WebSockets
using JSON
using HttpCommon
using Logging, LoggingExtras
using UUIDs

using ScottishTaxBenefitModel
using .BCCalcs
using .ModelHousehold
using .Utils
using .Definitions
using .SingleHouseholdCalculations
using .RunSettings
using .FRSHouseholdGetter
using .STBParameters
using .STBIncomes
using .STBOutput
using .Monitor
using .ExampleHelpers
using .Runner
using .SimplePovertyCounts: GroupPoverty
using .GeneralTaxComponents: WEEKS_PER_YEAR, WEEKS_PER_MONTH
using .Utils:md_format, qstrtodict

import Base.Threads.@spawn

const DEFAULT_PORT=8054
const DEFAULT_SERVER="http://localhost:$DEFAULT_PORT/"


@debug "server starting up"

include("runner_libs.jl")
include( "static_texts.jl")
include( "table_libs.jl")

STASHED_RESULTS = Dict{UUID,Any}()

function get_thing( thing::AbstractArray, key :: AbstractString, default :: AbstractString )
   for i in thing
      if i[1] == key
         return i[2]
      end
   end # loop
   default
end #get

function addqstrdict( app, req  :: Dict )
   req[:parsed_querystring] = qstrtodict(req[:query])
   return app(req)
end

# Better error handling
function errorCatch( app, req  :: Dict )
   try
      app(req)
   catch e
      @error "Error occured!"
      io = IOBuffer()
      showerror(io, e)
      err_text = takebuf_string(io)
      @error err_text
      resp = withHeaders(JSON.json(Dict("message" => err_text, "error" => true)), req)
      resp[:status] = 500
      return resp
   end
end

function d100( v :: Number ) :: Number
   v/100.0
end

function web_map_params( req  :: Dict, defaults = MiniTB.DEFAULT_PARAMS ) :: MiniTB.TBParameters
   querydict = req[:parsed_querystring]
   tbparams = deepcopy( defaults )
   tbparams.it_allow = get_if_set("it_allow", querydict, tbparams.it_allow, operation=weeklyise )
   tbparams.it_rate[1] = get_if_set("it_rate_1", querydict, tbparams.it_rate[1], operation=d100 )
   tbparams.it_rate[2] = get_if_set("it_rate_2", querydict, tbparams.it_rate[2], operation=d100 )
   tbparams.it_band[1] = get_if_set("it_band", querydict, tbparams.it_band[1], operation=weeklyise)
   tbparams.benefit1 = get_if_set("benefit1", querydict, tbparams.benefit1)
   tbparams.benefit2 = get_if_set("benefit2", querydict, tbparams.benefit2)
   tbparams.ben2_min_hours = get_if_set("ben2_min_hours", querydict, tbparams.ben2_min_hours)
   tbparams.ben2_taper = get_if_set("ben2_taper", querydict, tbparams.ben2_taper, operation=d100)
   tbparams.ben2_u_limit = get_if_set("ben2_u_limit", querydict, tbparams.ben2_u_limit)
   tbparams.basic_income = get_if_set("basic_income", querydict, tbparams.basic_income)
   @debug "DEFAULT_PARAMS\n$DEFAULT_PARAMS"
   @debug "tbparams\n$tbparams"
   tbparams
end

function main_run_to_json( tbparams :: MiniTB.TBParameters ):: String
   results = do_one_run( tbparams, num_households, num_people, NUM_REPEATS )
   summary_output = summarise_results!( results=results, base_results=BASE_STATE )
   JSON.json( summary_output )
end

function web_do_one_run( req :: Dict ) :: AbstractString
   @info "web_do_one_run; running on thread $(Threads.threadid())"
   tbparams = web_map_params( req )
   json = main_run_to_json( tbparams )
   # headers could include (e.g.) a timestamp, so add after caching
end # do_one_run



# Headers -- set Access-Control-Allow-Origin for either dev or prod
# this is from https://github.com/JuliaDiffEq/DiffEqOnlineServer
#
function add_headers( json :: AbstractString ) :: Dict
    headers  = HttpCommon.headers()
    headers["Content-Type"] = "application/json; charset=utf-8"
    headers["Access-Control-Allow-Origin"] = "*"
    Dict(
       :headers => headers,
       :body=> json
    )
end

function get_js_monitor_code( uuid :: UUID )/
   data = "{uuid:'$uuid'}";
   path = "/ubi/progress/";
   func = "
   function( remoteData, success, xhr, handle ){
      \$('#progress_indicator').html( remoteData );
   }\n";
   return "
   var updater = $.PeriodicalUpdater( '$path', { data:$data }, $function );";
end

#
# This is my attempt at starting a task using the 1.3 @spawn macro
# 1st parameter is a function that returns String (probably a json string) and accepts the req Dict
#
function do_in_thread( the_func::Function, req :: Dict ) :: Dict
   response = @spawn the_func( req )
   # note that the func returns a string but response is a Future type
   # line below converts response to a string
   @debug "do_in_thread response is $response"
   json = fetch( response )
   add_headers( json )
end

# configure logger; see: https://docs.julialang.org/en/v1/stdlib/Logging/index.html
# and: https://github.com/oxinabox/LoggingExtras.jl
logger = FileLogger("/var/tmp/stb_log.txt")
global_logger(logger)
LogLevel( Logging.Info )

function get_progress( uuid :: UUID )
   if haskey( PROGRES, uuid )
      p = PROGRESS[uuid]
   end   

   add_headers( json )
end

#
# from diffeq thingy instead of Mux.defaults
#
# ourstack = stack(Mux.todict, errorCatch, Mux.splitquery, Mux.toresponse) # from DiffEq
#
@app stbdemo = (
   Mux.defaults,
   addqstrdict,
   page( respond("<h1>A Scottish Tax-Benefit Model</h1>")),
   # handle main stb run a bit differently so we can
   # check & cache the results.
   # page("/stb", req -> web_do_one_run_cached( req )),
   page( "/ubi/progress/:uuid", req -> get_progress((req[:params][:uuid]))), # note no Headers
   page( "ubi/output/:uuid", req -> get_output((req[:params][:uuid]))), # note no Headers
   page("/ubi/run", req -> do_in_thread( web_do_one_bi, req )),
   Mux.notfound(),
)

port = DEFAULT_PORT
if length(ARGS) > 0
   port = parse(Int64, ARGS[1])
end

serve(stbdemo, port)

while true # FIXME better way?
   @debug "new STB Server; main loop; server running on port $port"
   sleep( 60 )
end