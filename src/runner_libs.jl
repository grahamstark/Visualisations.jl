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
end

PROGRESS = Dict{UUID,Any}()
STASHED_RESULTS = Dict{UUID,AllOutput}()

IN_QUEUE = Channel{ParamsAndSettings}(QSIZE)
OUT_QUEUE = Channel{AllOutput}(QSIZE)


function calc_one()
	params = take!( IN_QUEUE )
	res = do_run_a( params.sys, params.settings )
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

	aout = AllOutput( settings.uuid, results, outf, gl ) 
	put!( OUT_QUEUE, aout )
end


function submit_job( sys :: TaxBenefitSystem, settings :: Settings )
    uuid = UUIDs.uuid4()
	settings.uuid = uuid
    put!( IN_QUEUE, ParamsAndSettings(uuid, sys, settings ))
    return uuid
end

function take_jobs()
	while true
		res = take!( OUT_QUEUE )
		STASHED_RESULTS[ res.uuid ] = res
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
Retrieve one of the model's example households & overwrite a few fields
to make things simpler.
"""
function make_hh( 
	;
	tenure              :: Tenure_Type = Private_Rented_Unfurnished,
	bedrooms            :: Int = 2, 
	hcost               :: Real = 100.0, 
	marrstat            :: Marital_Status = Single, 
	chu5                :: Integer = 0, 
	ch5p                :: Integer = 0,
	head_earn           :: Real = 0.0,
	head_hours          :: Real = 0.0,
	head_age            :: Int = 25,
	head_private_pens   :: Real = 0.0
	spouse_earn         :: Real = 0.0,
	spouse_hours        :: Real = 0.0,
	spouse_age          :: Int = 0,
	spouse_private_pens :: Real = 0.0 ) :: Household
	hh = deepcopy(get_example( single_hh ))
	head = get_head(hh)
	head.age = head_age
	head.marital_status = marital_status
	empty!(head.income)
	head.income[wages] = head_earn
	head.income[private_pensions] = head_private_pens
	head.employment_status = if head_age > 66
		Retired 
		else
			if head_hours == 0
				Unemployed
			elseif head_hours < 20
				Part_time_Employee
			else
				Full_time_Employee
			end
		end
    head.actual_hours_worked = head.usual_hours_worked = head_hours
	enable!(head) # clear dla stuff from example
	hh.tenure = tenure
	hh.bedrooms = bedrooms
	hh.other_housing_charges = hh.water_and_sewerage = 0
	if hh.tenure == Mortgaged_Or_Shared
		hh.mortgage_payment = hcost
		hh.mortgage_interest = hcost
		hh.gross_rent = 0
	else
		hh.mortgage_payment = 0
		hh.mortgage_interest = 0
		hh.gross_rent = hcost
	end

	if marrstat in[Married_or_Civil_Partnership, Cohabiting]
		sex = head.sex == Male ? Female : Male # hetero ..
		add_spouse!( hh, spouse_age, sex )
		sp = get_spouse(hh)
		enable!(sp)
		sp.marital_status = marital_status
		empty!(sp.income)
		sp.income[wages] = spouse_earn
		sp.income[private_pensions] = spouse_private_pens
		sp.employment_status = if spouse_age > 66
			Retired 
			else
				if spouse_hours == 0
					(chu5+ch5p) > 0 ? Looking_after_family_or_home : Unemployed
				elseif spouse_hours < 20
					Part_time_Employee
				else
					Full_time_Employee
				end
			end
		sp.actual_hours_worked = sp.usual_hours_worked = spouse_hours
	end
	age = 0
	for ch in 1:chu5
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	age = 7
	for ch in 1:ch5p
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	set_wage!( head, 0, 10 )
	for (pid,pers) in hh.people
		# println( "age=$(pers.age) empstat=$(pers.employment_status) " )
		empty!( pers.income )
		empty!( pers.assets )
	end
	return hh
end

struct ExampleHH 
	picture :: String 
	label :: String
	description :: String
	hh :: Household 
end

const EXAMPLE_HHS = [
		ExampleHH("family1","Single Person, £25k", "Single female, aged 25, earning £25,000",
			make_hh(
				head_earn = 25_000/52.0,
				head_hours = 40 )),
		ExampleHH("family2","Single Parent, £25k", "Working single parent, 1 3-year old daughter, earning £25,000",
			make_hh(
				head_earn = 25_000/52.0,
				head_hours = 40,
				chu5 = 1 )),
		ExampleHH("family3","Unemployed Couple, 2 children", "Couple, neither currently working, with 2 children aged 7 and 9",
			make_hh(
				head_earn = 0.0,
				head_hours = 0,
				head_age = 30
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 30,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 2 )),
		ExampleHH("family4","Working Family £12,000, 2 children", "Couple, on low wages, with 2 children aged 6 and 10. She works, he says at home with the kids",
			make_hh(
				head_earn = 12_000/52.0,
				head_hours = 30,
				head_age = 35
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 2 )),
		ExampleHH("family5","Working Family £30,000, 2 children", "Couple, with 3 year old twins. He works, she says at home with the kids",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 220.0,
				head_earn = 35_000/52.0,
				head_hours = 40,
				head_age = 35
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				chu5 = 2 )),
		ExampleHH("family6","Working Family £70,000, 2 children", "Couple, with 2 children aged 6 and 2. Both work, each earning £35,000pa",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 320.0,
				head_earn = 35_000/52.0,
				head_hours = 40,
				head_age = 35
				spouse_earn = 35_000.0/52,
				spouse_hours = 40,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 1,
				chu5 = 1 )),
		ExampleHH("family8","Single female pensioner, aged 80", "A single pensioner, aged 80, with no private pension.",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 150.0,
				head_age = 80,
				marrstat = Single )),
		ExampleHH("family9","Pensioner couple, both aged 80", "A pensioner, both aged 80, with £100pw private pension.",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 150.0,
				head_private_pens = 100.0,
				head_age = 80,
				spouse_age = 80,
				marrstat = Married_or_Civil_Partnership ))
	]

function calc_examples( base :: TaxBenefitSystem, sys :: TaxBenefitSystem, settings :: Settings ) :: Vector
	v = []
	for hh in EXAMPLE_HHS
		bres = do_one_calc( hh, base, settings )
		pres = do_one_calc( hh, sys, settings )
		push!( v, ( bres, pres ))
	end
	return v
end

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
	println( "gl=$gl");   
	delete!( PROGRESS, settings.uuid )
	exres = calc_examples( BASE_STATE.sys, sys, settings )
	return (results=results, summary=outf,gain_lose=gl, examples=exres )
end 
