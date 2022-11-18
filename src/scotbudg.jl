
include( "uses.jl")
include( "types.jl")
include( "logger.jl")
## FIXME either use or replace
include( "examples.jl")
include( "display_constants.jl")
include( "static_texts.jl")
## FIXME shouldn't be needed
include( "text_html_libs.jl")
include( "runner_libs.jl")
include( "table_libs.jl")
include( "base_results.jl")
include( "param_constants.jl")

include( "dash_libs.jl")

const PREAMBLE = """

Every year the Scottish Government [sets its annual budget](https://www.gov.scot/publications/scottish-budget-2021-22/). 

This page lets you use a microsimulation tax-benefit model to experiment with some of the most important things that can be changed in the budget, 
and with some that currently can't because they are reserved to Westminster (reserved items are shown with a grey background). 

You can experiment with the difficult choices involved in balancing the need for fairness and equality against the need not to discourage people from working and saving.

For simplicity, only a few key items can be changed on this page. The [full model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl) allows changing
practically all aspects of the Scottish fiscal system that directly affect individuals. Full instructions on installing and using the full model on your own computer will follow presently.

"""


"""
Create the block of sliders and radios on the LHS
"""
function get_input_block()
	return dbc_form([
		dbc_row([
			dbc_col( it_fieldset() ),
			dbc_col( ni_fieldset() ),
			dbc_col( ben_fieldset() )			
		])
		dbc_row([
			dbc_col([
				submit_button()
			]) # col
		]) # row
	]) # form
end 


app = dash( 
	external_stylesheets=[dbc_themes.UNITED], 
	url_base_pathname="/scotbudg/" ) 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|

app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "A Budget for Scotland")
	html_h1("A Budget for Scotland"),
	dcc_markdown( PREAMBLE ),
	get_input_block(),		
	dcc_loading( 
		id="model_running", 
		type="default", 
		children = [
			html_div(
				id="loading-output-1"						
			) # div
		] # children
	), # loading
	html_div( id="output-block" ), 	
	html_div( dcc_markdown( ENDNOTES ))
end # layout

function do_output( br, hr, tr, pa, ni_prim, ni_sec, cb, pen, uct, ucs, wtcb, scp, scp_age )
	results = nothing
	cache_key = "$br, $hr, $tr, $pa, $ni_prim, $ni_sec, $cb, $pen, $uct, $ucs, $wtcb, $scp, $scp_age"
	sys = deepcopy( BASE_PARAMS )
	settings = deepcopy( BASE_SETTINGS )
	settings.uuid = UUIDs.uuid4()
	if (br != BASIC_RATE) || (hr !=HIGHER_RATE)||(tr !=TOP_RATE)||(uct != UC_TAPER )||(cb != CHILD_BENEFIT)||(pen!= PENSION)||(scp!=SCOTTISH_CHILD_PAYMENT)||(pa!=PERSONAL_ALLOWANCE)||(ni_prim!=NI_A)||(ni_sec!=NI_B)||(ucs!=UC_SINGLE)||(wtcb!=WTC_BASIC) || (scp_age != SCP_AGE)
		br /= 100.0
		hr /= 100.0
		tr /= 100.0
		uct /= 100.0
		pa /= WEEKS_PER_YEAR
		wtcb /= WEEKS_PER_YEAR
		ucs /= WEEKS_PER_MONTH

		ni_prim /= 100.0
		ni_sec /= 100.0

		if br == 0
			sys.it.non_savings_rates[1:3] .= 0.0
		else
			bincr = br-sys.it.non_savings_rates[2] 
			sys.it.non_savings_rates[1:3] .+= bincr
			sys.it.non_savings_rates[1] = max(0, sys.it.non_savings_rates[1]) 
		end
		sys.it.non_savings_rates[4] = hr
		sys.it.non_savings_rates[5] = tr
		sys.it.personal_allowance = pa
		sys.uc.taper = uct
		sys.lmt.working_tax_credit.basic = wtcb

		if ucs == 0
			sys.uc.age_25_and_over = 0.0
			sys.uc.age_18_24 = 0.0
			sys.uc.couple_both_under_25 = 0.0
			sys.uc.couple_oldest_25_plus = 0.0
		else
			ucsd = ucs - sys.uc.age_25_and_over
			# move main uc allows equally, as in covid uplift
			sys.uc.age_25_and_over = max(0.0, ucsd+sys.uc.age_25_and_over)
			sys.uc.age_18_24 = max(0.0, ucsd+sys.uc.age_18_24)		
			sys.uc.couple_both_under_25 = max(0.0, sys.uc.couple_both_under_25+ucsd)
			sys.uc.couple_oldest_25_plus = max(0.0,sys.uc.couple_oldest_25_plus+ucsd)
		end

		@debug "sys.nmt_bens.child_benefit.first_child was $(sys.nmt_bens.child_benefit.first_child) now $cb"
		sys.nmt_bens.child_benefit.first_child = cb
		@debug "sys.nmt_bens.pensions.new_state_pension was $(sys.nmt_bens.pensions.new_state_pension) now $pen"
		sys.nmt_bens.pensions.new_state_pension = pen
		sys.scottish_child_payment.amount = scp
		sys.scottish_child_payment.maximum_age = scp_age
		sys.ni.primary_class_1_rates[3] = ni_prim
		sys.ni.secondary_class_1_rates[2:3] .= ni_sec
		
		results = do_run_a( cache_key, sys, settings )
	else
		@debug "returning base results"
		results = BASE_RESULTS
	end
	println("sys.it.non_savings_rates $(sys.it.non_savings_rates)")
	println("BASE_PARAMS.it.non_savings_rates $(BASE_PARAMS.it.non_savings_rates)")
	return make_output_table( results, sys )
end 

function no_nothings( things ...)::Bool
	for thing in things 
		if isnothing( thing )  
			return false
		end
	end
	return true
end

callback!(
    app,
    Output("model_running",  "children"),
	Output("output-block", "children"),
	Input("submit-button", "n_clicks"),

	State( "basic_rate", "value"),
	State( "higher_rate", "value"),
	State( "top_rate", "value"),
	State( "pa", "value"),

	State( "ni_prim", "value"),
	State( "ni_sec", "value"),
	
	State( "cb", "value"),
	State( "pen", "value"),
	State( "uctaper", "value"),
	State( "ucs", "value"),
	State( "wtcb", "value"),
	State( "scp", "value"),
	State( "scp_age", "value")

	) do n_clicks, basic_rate, higher_rate, top_rate, pa, 
	     ni_prim, ni_sec, 
		 cb, pen, uctaper, ucs, wtcb, scp, scp_age

	println( "n_clicks = $n_clicks")
	# will return 'nothing' if something is out-of-range or not a number, or if no clicks on submit
	if no_nothings( n_clicks, basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, cb, pen, uctaper, ucs, wtcb, scp, scp_age )
		println( "running the live calc version")
		return [nothing, do_output( basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, cb, pen, uctaper, ucs, wtcb, scp, scp_age )]
	end
	println( "doing the do-nothing version")
	[nothing, do_output( 
		BASIC_RATE, HIGHER_RATE,  TOP_RATE,  PERSONAL_ALLOWANCE, 
		NI_A, NI_B, 21.15, 179.60, 
		55, 324.84, 2_005, 10.0, 5 )]
end

run_server( app, "0.0.0.0", 8052; debug=true )