include( "uses.jl")
include( "runner_libs.jl")
include( "table_libs.jl")
include( "dash_libs.jl")

const PREAMBLE = """
...

"""

function one_mt_box( name :: String, prefix :: String )
	dbc_row([
		dbc_col( dbc_label(name) ),
		dbc_col(
			dcc_radioitems(
			options =[
				Dict("label" => "Keep as-is", "value" => "$(prefix)_nc"),
				Dict("label" => "Abolish Completely", "value" => "$(prefix)_abolish"),
				Dict("label" => "Keep Housing Benefits only", "value" => "$(prefix)_asincome")
			],
			value="$(prefix)_nc") # radio
		) # col
	]) # row
end

function bi_ben_fieldset()
	bi = html_fieldset([
		html_legend( "Treatment of Existing Benefits"),
		one_mt_box( "Means Tested Benefits", "mtbs" ),		

		dbc_row([
			dbc_col( 
                dbc_label("Make BI Taxable?"; html_for="bi_tax")
			),
			dbc_col( 
				dbc_checkbox( id="bi_tax", value=false)
			)


		]
		),
		dbc_row([
			dbc_col( 
                dbc_label("Retain Sickness Benefits?"; html_for="sickben")
			),
			dbc_col( 
				
			)
		])
    ])
	bi
end

"""
Create the block of sliders and radios on the LHS
"""
function get_input_block()
	return dbc_form([
		dbc_row([
			dbc_col( it_fieldset() ),
			dbc_col( bi_ben_fieldset() ),
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
	url_base_pathname="/basicincome/" ) 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|

app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "Basic Income")
	html_h1("BI for Scotland"),
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

function do_output( br, hr, tr, pa, ni_prim, ni_sec, cb, pen, uct, ucs, wtcb, scp )
	results = nothing
	sys = deepcopy( BASE_STATE.sys )
	# 21.15, 179.60, 10.0

	# 20, 41, 46, 12_570, 12, 13.8, 21.15, 179.60, 55, 324.84, 2_005, 10.0 

	if (br != 20) || (hr !=41)||(tr !=46)||(uct != 55 )||(cb != 21.15)||(pen!= 179.60)||(scp!=10)||(pa!=12_570)||(ni_prim!=12)||(ni_sec!=13.8)||(ucs!=324.84)||(wtcb!=2_005) 
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

		sys.nmt_bens.child_benefit.first_child = cb
		sys.nmt_bens.pensions.new_state_pension = pen
		sys.scottish_child_payment.amount = scp
		sys.ni.primary_class_1_rates[3] = ni_prim
		sys.ni.secondary_class_1_rates[2:3] .= ni_sec


		sys.ubi.abolished = true
		sys.ubi.adult_amount = 4_800.0
		sys.ubi.child_amount= 3_000.0
		sys.ubi.universal_pension = 8_780.0
		sys.ubi.adult_age = 17
		sys.ubi.retirement_age = 66

		#=
		sys.uc.abolished :
		sys.uc.other_income 
		incomes     = LEGACY_MT_INCOME
        hb_incomes  = LEGACY_HB_INCOME
        pc_incomes  = LEGACY_PC_INCOME
        sc_incomes  = LEGACY_SAVINGS_CREDIT_INCOME
		=#

		results = do_run( sys )
	else
		results = ( 
			results = BASE_STATE.results,
			summary = BASE_STATE.summary, 
			gain_lose = BASE_STATE.gain_lose )
	end



	println("sys.it.non_savings_rates $(sys.it.non_savings_rates)")
	println("BASE_STATE.sys.it.non_savings_rates $(BASE_STATE.sys.it.non_savings_rates)")
	return make_output_table(results,sys)
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
	State( "scp", "value")

	) do n_clicks, basic_rate, higher_rate, top_rate, pa, 
	     ni_prim, ni_sec, 
		 cb, pen, uctaper, ucs, wtcb, scp

	println( "n_clicks = $n_clicks")
	# will return 'nothing' if something is out-of-range or not a number, or if no clicks on submit
	if no_nothings( n_clicks, basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, cb, pen, uctaper, ucs, wtcb, scp )
		println( "running the live calc version")
		return [nothing, do_output( basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, cb, pen, uctaper, ucs, wtcb, scp )]
	end
	println( "doing the do-nothing version")
	[nothing, do_output( 20, 41, 46, 12_570, 12, 13.8, 21.15, 179.60, 55, 324.84, 2_005, 10.0 )]
end

run_server( app, "0.0.0.0", 8053; debug=true )