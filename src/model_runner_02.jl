using Dash
using PlotlyJS
using DashBootstrapComponents
using Formatting
using PovertyAndInequalityMeasures
using StatsBase

#, DashHtmlComponents, DashCoreComponents

using Markdown
using DataFrames

include( "run_and_consts.jl")
include( "summary_tables.jl")
include( "plotly_plots.jl")

const FORM_EXTRA =Dict(
	"border-bottom"=>"1px dashed #aaaaaa", 
	"margin-bottom"=>"5px",
	"margin-top"=>"5px")

const TOOLTIP_PROPS = Dict(
		"placement"=>"bottom", 
		"always_visible"=> true)

const PREAMBLE = """

Every year the Scottish Government [sets its annual budget](https://www.gov.scot/publications/scottish-budget-2021-22/). This page lets you use a microsimulation tax-benefit model to experiment with
some of the most important things that the Scottish Government can change, and with some that they currently can't because they are reserved to Westminster (reserved items are shown with a grey background).
You can experiment with the difficult choices involved in balancing fairness against the need not to worsen incentives to work and save.

For simplicity, only a few key items can be changed on this page. The [full model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl) allows changing
practically all aspects of the Scottish fiscal system that directly affect individuals. Full instructions on installing and using the full model on your own computer will follow presently.

"""

const INFO = """

#### Notes

* Scotland actually has 3 lower rates of income tax rather than the single 20% basic rate shown - currently 19%,20% and 21%. Changing the 20% 'basic rate'
causes all three to move in sync.

#### Key Assumptions

* No behavioural changes - increasing or decreasing taxes doesn't cause people to change how they work and earn;
* the model reports entitlements to benefits and liability to taxes, not receipts and payments - so we may overstate the costs of benefits since some will not be taken up. On taxes, some may be paid with a considerable delay, and some evaded or avoided.
* see [the blog](https://stb-blog.virtual-worlds.scot/) for more gory details (*content warning - very boring and rambling)*.

#### Known Problems

This is a new model. I'm now reasonably confident of its essential accuracy - it passes an [extensive test suite](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/test) but there are some aspects that
require investigation in the coming months. Notably:

* Income Tax revenues seem to be overstated by around £1bn pa compared to [official forecasts](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/). Possibly much of this is due to how pension tax relief is treated;
* measures of inequality seem low compared to official statistics.

Please if you spot anything odd or if you have any suggestions. And I'd very much welcome contributions. You can:

* [Open an issue on GitHub](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/issues); or
* [email me](mailto:graham.stark@virtual-worlds.biz).

### To Find Out More

You'll have to do some reading, I'm afraid. Some links:

* **Tax Benefit Models**: [A short introduction](https://stb.virtual-worlds.scot/intro.html)  *(originally written for the Open University; uses an obselete version of this model*) | [Blog Posts about the Model](https://stb-blog.virtual-worlds.scot/);
* **Poverty and Inequality**: [My Notes](https://stb.virtual-worlds.scot/poverty.html) | [World Bank Handbook](http://documents.worldbank.org/curated/en/488081468157174849/Handbook-on-poverty-and-inequality) | [Official Figures for Scotland](https://data.gov.scot/poverty/);
* **Scotland's Finances**: [Scottish Fiscal Commission](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/) | [Scottish Government Budget Documents](https://www.gov.scot/budget/).


* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Poverty and Inequality Measures](https://github.com/grahamstark/PovertyAndInequalityMeasures.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).

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
	html_div( dcc_markdown( INFO ))
end # layout

function do_output( br, hr, tr, pa, ni_prim, ni_sec, uct, cb, pen, scp )
	results = nothing
	sys = deepcopy( BASE_STATE.sys )
	# 21.15, 179.60, 10.0
	if (br != 20) || (hr !=41)||(tr !=46)||(uct != 55 )||(cb != 21.15)||(pen!= 179.60)||(scp!=10)||(pa!=12_570)||(ni_prim!=12)||(ni_sec!=13.8)
		br /= 100.0
		hr /= 100.0
		tr /= 100.0
		uct /= 100.0
		pa /= WEEKS_PER_YEAR
		ni_prim /= 100.0
		ni_sec /= 100.0

		bincr = br-sys.it.non_savings_rates[2] 
		sys.it.non_savings_rates[1:3] .+= bincr
		sys.it.non_savings_rates[4] = hr
		sys.it.non_savings_rates[5] = tr
		sys.it.personal_allowance = pa
		sys.uc.taper = uct
		sys.nmt_bens.child_benefit.first_child = cb
		sys.nmt_bens.pensions.new_state_pension = pen
		sys.scottish_child_payment.amount = scp
		sys.ni.primary_class_1_rates[3] = ni_prim
		sys.ni.secondary_class_1_rates[2:3] .= ni_sec

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
	
	State( "uctaper", "value"),
	State( "cb", "value"),
	State( "pen", "value"),
	State( "scp", "value")

	) do n_clicks, basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, uctaper, cb, pen, scp

	println( "n_clicks = $n_clicks")
	# will return 'nothing' if something is out-of-range or not a number, or if no clicks on submit
	if no_nothings( n_clicks, basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, uctaper, cb, pen, scp )
		return [nothing, do_output( basic_rate, higher_rate, top_rate, pa, ni_prim, ni_sec, uctaper, cb, pen, scp )]
	end
	[nothing, do_output( 20, 41, 46, 12_570, 12, 13.8, 55, 21.15, 179.60, 10.0 )]
end

run_server( app, "0.0.0.0", 8052; debug=true )