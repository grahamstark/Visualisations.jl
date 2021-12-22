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

# FIXME we can simplify this by directly creating the outputs
# as a string and just saving that in STASHED_RESULTS
STASHED_RESULTS = Dict{UUID,AllOutput}()

# Save results by query string & just return that
# TODO complete this.
CACHED_RESULTS = Dict{String,String}()

IN_QUEUE = Channel{ParamsAndSettings}(QSIZE)

"""
Wait to pull a job off the job queue and sent it
to the calculator. FIXME should also just generate text output.
"""
function calc_one()
	while true
		@debug "calc_one entered"
		params = take!( IN_QUEUE )
		@debug "params taken from IN_QUEUE; got params uuid=$(params.settings.uuid)"
		aout = do_run_a( params.sys, params.settings )
		@debug "model run OK; putting results into STASHED_RESULTS"
		STASHED_RESULTS[ aout.uuid ] = aout
	end
	# put!( OUT_QUEUE, aout )
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
	@debug "do_run_a entered"
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
	exres = calc_examples( BASE_STATE.sys, sys, settings )
	aout = AllOutput( settings.uuid, results, outf, gl, exres ) 
	return aout;
end


function submit_job( sys :: TaxBenefitSystem, settings :: Settings )
    uuid = UUIDs.uuid4()
	@debug "submit_job entered uuid=$uuid"
	settings.uuid = uuid
    put!( IN_QUEUE, ParamsAndSettings(uuid, sys, settings ))
	@debug "submit exiting queue is now $IN_QUEUE"
    return uuid
end

"""
Old runner version used in scotbudg 
"""
function do_run( sys :: TaxBenefitSystem, init = false )::NamedTuple
	settings = deepcopy( BASE_STATE.settings )
	settings.uuid = UUIDs.uuid4()
	obs = Observable(Progress(settings.uuid, "",0,0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
    results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], settings ) 
	delete!( PROGRESS, settings.uuid )	
	return (results=results, summary=outf,gain_lose=gl  )
end 
