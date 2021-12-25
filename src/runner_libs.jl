#
# Basic import for any visualisation that runs the full model.
# Create a base set of results, settings and parameters and
# import everything we might reasonably need.#
#
# fixme extend to multiple systems

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

function do_run_a( 
	cache_key, 
	sys :: TaxBenefitSystem, 
	settings :: Settings ) :: AllOutput
	@debug "do_run_a entered"
	obs = Observable( 
		Progress(settings.uuid, "",0,0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	results = do_one_run( settings, [sys], obs )
	settings.poverty_line = make_poverty_line( results.hh[1], settings )        
    
	outf = summarise_frames( results, settings )
	gl = make_gain_lose( BASE_RESULTS.results.hh[1], results.hh[1], settings ) 
	exres = calc_examples( BASE_PARAMS, sys, settings )
	aout = AllOutput( settings.uuid, cache_key, results, outf, gl, exres ) 
	return aout;
end

"""
Runner version used in scotbudg without the caching stuff 
"""
function do_run( sys :: TaxBenefitSystem, init = false )::NamedTuple
	settings = deepcopy( BASE_SETTINGS )
	settings.uuid = UUIDs.uuid4()
	obs = Observable(Progress(settings.uuid, "",0,0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
    results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, settings )
	gl = make_gain_lose( BASE_RESULTS.results.hh[1], results.hh[1], settings ) 
	delete!( PROGRESS, settings.uuid )	
	return (results=results, summary=outf,gain_lose=gl  )
end