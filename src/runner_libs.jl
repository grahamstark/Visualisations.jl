#
# Basic import for any visualisation that runs the full model.
# Create a base set of results, settings and parameters and
# import everything we might reasonably need.#
#

const QSIZE = 32

# fixme extend to multiple systems
struct ParamsAndSettings 
	uuid         :: UUID
	sys          :: TaxBenefitSystem
	settings     :: Settings
end

struct AllOutput
	uuid         :: UUID
	results     
	summary    
	gain_lose
	examples
end

PROGRESS = Dict{UUID,Any}()
STASHED_RESULTS = Dict{UUID,AllOutput}()

IN_QUEUE = Channel{ParamsAndSettings}(QSIZE)
OUT_QUEUE = Channel{AllOutput}(QSIZE)


function calc_one()
	params = take!( IN_QUEUE )
	@debug "calc_one entered"
	do_run_a( params.sys, params.settings )
end

function load_system()::TaxBenefitSystem
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	#
	# Note that as of Budget21 removing these doesn't actually happen till May 2022.
	#
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	# uc taper to 55
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "budget_2021_uc_changes.jl"))
	weeklyise!( sys )
	return sys
end

struct BaseState
	sys          :: TaxBenefitSystem
	settings     :: Settings
	results      :: NamedTuple
	summary      :: NamedTuple
	gain_lose    :: NamedTuple
end

function initialise()::BaseState
    settings = Settings()
	settings.uuid = UUIDs.uuid4()
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	settings.income_data_source = ds_frs
	settings.dump_frames = false
	settings.do_marginal_rates = true
	settings.requested_threads = 4
	sys = load_system()

	tot = 0
	obs = Observable( Progress(settings.uuid,"",0,0,0,0))
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	results = do_one_run( settings, [sys], obs )
	settings.poverty_line = make_poverty_line( results.hh[1], settings )
	summary = summarise_frames( results, settings )
	popn = summary.inequality[1].total_population
	gainlose = ( 
		gainers=0.0, 
		losers=0.0,
		nc=popn, 
		popn = popn )	
	delete!( PROGRESS, settings.uuid )
	return BaseState( sys, settings, results, summary, gainlose )
end

const BASE_STATE = initialise()

function do_run_a( sys :: TaxBenefitSystem, settings :: Settings )
	global obs

	obs = Observable( 
		Progress(settings.uuid, "",0,0,0,0))
		# UUID("00000000-0000-0000-0000-000000000000"),"",		
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, BASE_STATE.settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], BASE_STATE.settings ) 
	println( "gl=$gl");  
	exres = calc_examples( BASE_STATE.sys, sys, settings )
	aout = AllOutput( settings.uuid, results, outf, gl, exres ) 
	put!( OUT_QUEUE, aout )
	
end


function submit_job( sys :: TaxBenefitSystem, settings :: Settings )
    uuid = UUIDs.uuid4()
	@debug "submit_job entered uuid=$uuid"
	settings.uuid = uuid
    put!( IN_QUEUE, ParamsAndSettings(uuid, sys, settings ))
	@debug "submit exiting queue is now $IN_QUEUE"
    return uuid
end

function take_jobs()
	while true
		@debug "take jobs loop start"
		res = take!( OUT_QUEUE )
		@debug "OUT_QUEUE is $OUT_QUEUE"
		STASHED_RESULTS[ res.uuid ] = res
		@debug "take jobs loop end"
	end
end

#=
function start_handlers(n::Int)
	for i in 1:n # start n tasks to process requests in parallel
		errormonitor(@async calc_one())
	end
	errormonitor(@async take_jobs())
end
=#


"""
Old version still used in scotbudg 
"""
function do_run( sys :: TaxBenefitSystem, init = false )::NamedTuple
	obs = Observable( Progress("",0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	setttings = deepcopy( BASE_STATE.settings )
	settings.uuid = uuid
    results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, BASE_STATE.settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], BASE_STATE.settings ) 
	delete!( PROGRESS, settings.uuid )	
	return (results=results, summary=outf,gain_lose=gl  )
end 
