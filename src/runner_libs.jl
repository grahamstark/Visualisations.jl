#
# Basic import for any visualisation that runs the full model.
# Create a base set of results, settings and parameters and
# import everything we might reasonably need.#
#

const QSIZE = 32

# fixme extend to multiple systems
struct ParamsAndSettings 
	uuid         :: UUID
	cache_key    :: String
	sys          :: TaxBenefitSystem
	settings     :: Settings
end

struct AllOutput
	uuid         :: UUID
	cache_key    :: String 
	results     
	summary    
	gain_lose
	examples
end

PROGRESS = Dict{UUID,Any}()

# FIXME we can simplify this by directly creating the outputs
# as a string and just saving that in STASHED_RESULTS
STASHED_RESULTS = Dict{UUID,Any}()

# Save results by query string & just return that
# TODO complete this.
CACHED_RESULTS = Dict{String,Any}()

IN_QUEUE = Channel{ParamsAndSettings}(QSIZE)

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

function initialise_settings()::Settings
    settings = Settings()
	settings.uuid = UUIDs.uuid4()
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	settings.income_data_source = ds_frs
	settings.dump_frames = false
	settings.do_marginal_rates = true
	settings.requested_threads = 4
	return settings
end

function do_run_a( cache_key, sys :: TaxBenefitSystem, settings :: Settings ) :: AllOutput
	global obs
	@debug "do_run_a entered"
	obs = Observable( 
		Progress(settings.uuid, "",0,0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, BASE_STATE.settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], BASE_STATE.settings ) 
	exres = calc_examples( BASE_STATE.sys, sys, settings )
	aout = AllOutput( settings.uuid, cache_key, results, outf, gl, exres ) 
	return aout;
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