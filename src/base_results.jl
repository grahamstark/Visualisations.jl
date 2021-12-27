

#
const BASE_UUID = UUID("985c312f-129b-4acd-9e40-cb629d184183")
const BASE_PARAMS = load_system()


function initialise_settings()::Settings
    settings = Settings()
	settings.uuid = BASE_UUID
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	settings.income_data_source = ds_frs
	settings.dump_frames = false
	settings.do_marginal_rates = true
	settings.requested_threads = 4
	settings.dump_frames = true
	return settings
end

const BASE_SETTINGS = initialise_settings()

## FIXME POVERTY LINE!
function make_base_results()
    obs = Observable( 
		Progress(BASE_SETTINGS.uuid, "",0,0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
    settings = deepcopy(BASE_SETTINGS)
	results = do_one_run( settings, [BASE_PARAMS], obs )
    println( BASE_PARAMS)
    println( settings )
    settings.poverty_line = make_poverty_line( results.hh[1], settings )        
    outf = summarise_frames( results, settings )
	gl = make_gain_lose( results.hh[1], results.hh[1], settings ) 
	exres = calc_examples( BASE_PARAMS, BASE_PARAMS, settings )
    println( settings.poverty_line)
	aout = AllOutput( BASE_SETTINGS.uuid, "DEFAULT", results, outf, gl, exres ) 
	return aout;
end

const BASE_RESULTS = make_base_results()
const BASE_TEXT_OUTPUT = results_to_html( BASE_UUID, BASE_RESULTS, BASE_RESULTS )