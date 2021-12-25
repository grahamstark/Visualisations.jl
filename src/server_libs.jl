#
# see: https://github.com/JuliaWeb/Mux.jl
# and:
#

@debug "server starting up"

include( "uses.jl")
include( "types.jl")
include( "logger.jl")
include( "examples.jl")
include( "display_constants.jl")
include( "static_texts.jl")
include( "table_libs.jl")
include( "text_html_libs.jl")
include( "runner_libs.jl" )
include( "base_results.jl")
include( "queue_libs.jl")

# example for json3 StructTypes.@Struct T

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
   @debug "req=$req"
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
      resp = withHeaders(JSON3.write(Dict("message" => err_text, "error" => true)), req)
      resp[:status] = 500
      return resp
   end
end

function d100( v :: Number ) :: Number
   v/100.0
end

function web_map_params( req  :: Dict ) :: TaxBenefitSystem
   querydict = req[:parsed_querystring]
   sys = deepcopy( BASE_PARAMS )
   d = req[:parsed_querystring]

   sys.ubi.abolished = false 
   sys.ubi.adult_amount = d["bi_adult"]/WEEKS_PER_YEAR
   sys.ubi.child_amount = d["bi_child"]/WEEKS_PER_YEAR
   sys.ubi.universal_pension  = d["bi_pensioner"]/WEEKS_PER_YEAR
   sys.ubi.adult_age = d["bi_adult_age"]
   sys.ubi.retirement_age = d["bi_pens_age"]
   sys.ubi.mt_bens_treatment = 
      if d["ubi_mtbens_abolish"]
         ub_abolish
      elseif d["ubi_mtbens_keep_as_is"]
         ub_as_is
      elseif d["ubi_mtbens_keep_housing"]
         ub_keep_housing
      else
         @assert false "no assignment for ubi.mt_bens_treatment"
      end   
   sys.ubi.abolish_sickness_bens = d["ubi_abolish_sick"]
   sys.ubi.abolish_pensions = d["ubi_abolish_pensions"]
   sys.ubi.abolish_jsa_esa = d["ubi_abolish_esa"]
   sys.ubi.abolish_others = d["ubi_abolish_others"]
   sys.ubi.ub_as_mt_income = d["ubi_as_mt_income"]
   sys.ubi.ub_taxable = d["ubi_taxable"]
   sys.it.personal_allowance = d["it_pa"]/WEEKS_PER_YEAR
   br = d["it_basic_rate"] /=100.0
   if br == 0
      sys.it.non_savings_rates[1:3] .= 0.0
   else
      bincr = br-sys.it.non_savings_rates[2] 
      sys.it.non_savings_rates[1:3] .+= bincr
      sys.it.non_savings_rates[1] = max(0, sys.it.non_savings_rates[1]) 
   end
   sys.it.non_savings_rates[4] = d["it_higher_rate"] / 100.0
   sys.it.non_savings_rates[5] = d["it_top_rate"] / 100.0     
   make_ubi_pre_adjustments!( sys )
   return sys
end

function web_map_settings( req  :: Dict ) :: Settings
   querydict = req[:parsed_querystring]
   settings = deepcopy( BASE_SETTINGS )
   # ...
   return settings
end

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

function get_results( u :: AbstractString ):: Dict
   uuid = UUID(u)
   if haskey( CACHED_RESULTS[res.cache_key])

   end
end

function get_progress( u :: AbstractString ) :: Dict
   uuid = UUID(u)
   state = ( uuid=u, phase="missing", count=0, total=0 )
   if haskey( PROGRESS, uuid )
      @debug "get_progress entered uuid=|$u| key is in progress;"
      p = PROGRESS[uuid]
      @debug "phase is $(p.progress.phase)"
      if p.progress.phase == "end"
         @debug "get_progress: phase end"
         state = STASHED_RESULTS[uuid]
         @debug "got state for STASHED_RESULTS; uuid=$uuid"
         delete!( PROGRESS, uuid )
         @debug( "deleted $uuid progress")
      else
         state = ( uuid=p.progress.uuid, phase=p.progress.phase, count=p.progress.count, total=11_000 )
      end
   end  
   @debug "PROGRESS now $PROGRESS"     
   json = JSON3.write( state )
   return add_headers( json )    
end

function get_base( req :: Dict )
   @debug "returning base results"
   return add_headers( JSON3.write(BASE_TEXT_OUTPUT))
 end

function submit_model( req :: Dict )
   query = req[:query]
   @debug "submit model entered with query $query"
   if haskey( CACHED_RESULTS, query )
      @debug "returning results from cache"
      return add_headers( JSON3.write(CACHED_RESULTS[query]))
   end
   sys = web_map_params( req )
   @debug "submit_model  - starting mapping params"
   settings = web_map_settings( req )
   uuid = submit_job( req[:query], sys, settings )
   @debug "submit_model uuid=$uuid"    
   json = add_headers( JSON3.write( uuid ))
   return json
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
   page( "/bi/progress/:uuid", req -> get_progress((req[:params][:uuid]))), # note no Headers
   page("/bi/run/", req -> submit_model( req )),
   page("/bi/base/", req -> get_base( req )),
   Mux.notfound(),
)
