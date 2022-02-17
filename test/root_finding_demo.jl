using Roots

using UUIDs
using Observables
using CSV

using ScottishTaxBenefitModel
using .BCCalcs
using .Definitions
using .ExampleHelpers
using .FRSHouseholdGetter
using .GeneralTaxComponents
using .ModelHousehold
using .Monitor
using .Results
using .Runner
using .RunSettings
using .SimplePovertyCounts: GroupPoverty
using .SingleHouseholdCalculations
using .STBIncomes
using .STBOutput
using .STBParameters
using .Utils




const BASE_UUID = UUID("985c312f-129b-4acd-9e40-cb629d184183")

function initialise_settings()::Settings
    settings = Settings()
	settings.uuid = BASE_UUID
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	settings.income_data_source = ds_frs
	settings.dump_frames = false
	settings.do_marginal_rates = false
	settings.requested_threads = 4
	settings.dump_frames = true
	return settings
end

const BASE_SETTINGS = initialise_settings()

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

settings = initialise_settings()

sys = load_system()
chsys = deepcopy( sys )
chsys.scottish_child_payment.amount = 20.0

params = [sys, chsys]
            
# results = do_one_run( settings, params, obs )

mutable struct Thing
    a :: Float64
end

mutable struct RunParameters{T<:AbstractFloat}
    params :: TaxBenefitSystem{T}
    settings :: Settings
end

function run( x :: Number, things :: RunParameters )
    obs = Observable( 
		Progress(settings.uuid, "",0,0,0,0))
    nsr = deepcopy( things.params.it.non_savings_rates )
    things.params.it.non_savings_rates .+= x
    results = do_one_run(things.settings, [things.params], obs )
    things.params.it.non_savings_rates = nsr
    x^2 + things.params.it.non_savings_rates[1] 
end

things = RunParameters( chsys, settings )

zerorun = ZeroProblem( run, 0.0 )

solve( zerorun, things )