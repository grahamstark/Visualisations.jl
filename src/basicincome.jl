using Dash
using PlotlyJS
using DashBootstrapComponents
using Formatting
using PovertyAndInequalityMeasures
using StatsBase

#, DashHtmlComponents, DashCoreComponents

using Markdown
using DataFrames

include( "runner_libs.jl")
include( "table_libs.jl")
include( "dash_libs.jl")

const PREAMBLE = """
...

"""

const INFO = """

#### Notes

* Scotland actually has 3 lower rates of income tax rather than the single 20% basic rate shown - currently 19%,20% and 21%. Changing the 20% 'basic rate'
causes all three to move in sync.
* Likewise, changing the *Universal Credit: single 25+ adult* field changes the rates for young people and couples. 
* Scotland is [in the process of switching working-age families to Universal Credit from 'Legacy Benefits' (Income Support, Housing Benefit, etc.) ](https://commonslibrary.parliament.uk/constituency-data-universal-credit-roll-out/). I've written a [note on how this is modelled](https://stb-blog.virtual-worlds.scot/articles/2021/11/12/uc-legacy.html) - the code is [here](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/UCTransition.jl);
* the [£20pw 'uplift' to Universal Credit and Working Tax Credit](https://www.legislation.gov.uk/uksi/2021/313/pdfs/uksiem_20210313_en.pdf), now [scheduled for removal in April 2022](https://www.gov.uk/government/news/budget-2021-what-you-need-to-know) is modelled as already removed. 

#### Key Assumptions

* *No behavioural changes*: increasing or decreasing taxes doesn't cause people to change how they work and earn;
* the model reports *entitlements to benefits and liability to taxes*, not receipts and payments - so we may overstate the costs of benefits since some eligible families may not claim the things they're entitled to. With taxes, some may be paid with a considerable delay, and some evaded or avoided.

See [the model blog](https://stb-blog.virtual-worlds.scot/) for more gory details (*content warning - very boring and rambling)*.

#### Known Problems

This is a new model. I'm now reasonably confident of its essential accuracy - it passes an [extensive test suite](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/test) but there are some aspects that
require investigation in the coming months. Notably:

* Income Tax revenues seem to be overstated by around £1bn pa compared to [official forecasts](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/). Possibly much of this is due to how pension tax relief is treated;
* measures of inequality seem low compared to official statistics.

I'd very much welcome contributions and suggestions. If you spot anything odd or if you have any ideas for how this can be improved, you can:

* [Open an issue on GitHub](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/issues); or
* [email me](mailto:graham.stark@virtual-worlds.biz).

### To Find Out More

You'll have to do some reading, I'm afraid. Some links:

* **Tax Benefit Models**: [A short introduction to microsimulation and tax benefit models](https://stb.virtual-worlds.scot/intro.html). Originally written for the Open University, it covers all the essential ideas. | [Blog Posts about the Model](https://stb-blog.virtual-worlds.scot/);
* **Poverty and Inequality**: [My Notes](https://stb.virtual-worlds.scot/poverty.html) | [World Bank Handbook](http://documents.worldbank.org/curated/en/488081468157174849/Handbook-on-poverty-and-inequality) | [Official Figures for Scotland](https://data.gov.scot/poverty/);
* **Scotland's Finances**: [Scottish Fiscal Commission](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/) | [Scottish Government Budget Documents](https://www.gov.scot/budget/).


* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Poverty and Inequality Measures](https://github.com/grahamstark/PovertyAndInequalityMeasures.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).

"""

function one_mt_box( name :: String, prefix :: String )
	dbc_row([
		dbc_col( dbc_label(name) ),
		dbc_col(
			dcc_radioitems(
			options =[
				Dict("label" => "Keep as-is", "value" => "$(prefix)_nc"),
				Dict("label" => "Abolish", "value" => "$(prefix)_abolish"),
				Dict("label" => "Include UBI as income", "value" => "$(prefix)_asincome")
			],
			value="$(prefix)_nc") # radio
		) # col
	]) # row
end

function bi_ben_fieldset()
	bi = html_fieldset([
		html_legend( "Treatment of Existing Benefits"),
		one_mt_box( "Universal Credit", "uc" ),		
		one_mt_box( "Working Tax Credit", "wtc" ),
		one_mt_box( "Child Tax Credit", "ctc" ),
		one_mt_box( "Housing Benefit/CT Rebates", "hb" ),
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

function bi_ben_fieldset()
	ben = html_fieldset([

	])
	ben
end

"""
Create the block of sliders and radios on the LHS
"""
function get_input_block()
	return dbc_form([
		dbc_row([
			dbc_col( it_fieldset() ),
			dbc_col( bi_fieldset() ),
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
	html_div( dcc_markdown( INFO ))
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

		sys.uc.abolished :
		sys.uc.other_income 
		incomes     = LEGACY_MT_INCOME
        hb_incomes  = LEGACY_HB_INCOME
        pc_incomes  = LEGACY_PC_INCOME
        sc_incomes  = LEGACY_SAVINGS_CREDIT_INCOME


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