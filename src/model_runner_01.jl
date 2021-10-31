
using Dash
using PlotlyJS
using DashBootstrapComponents
#, DashHtmlComponents, DashCoreComponents

using Markdown
using DataFrames

include( "run_and_consts.jl")

const FORM_EXTRA =Dict(
	"border-bottom"=>"1px dashed #aaaaaa", 
	"margin-bottom"=>"5px",
	"margin-top"=>"5px")

const PREAMBLE = """
"""


#=
function basic_run( ; print_test :: Bool, mtrouting :: MT_Routing  )
    settings.means_tested_routing = mtrouting
    settings.run_name="run-$(mtrouting)-$(date_string())"
    sys = [get_system(scotland=false), get_system( scotland=true )]
    results = do_one_run( settings, sys )
    h1 = results.hh[1]
    pretty_table( h1[:,[:weighted_people,:bhc_net_income,:eq_bhc_net_income,:ahc_net_income,:eq_ahc_net_income]] )
    settings.poverty_line = make_poverty_line( results.hh[1], settings )
    dump_frames( settings, results )
    println( "poverty line = $(settings.poverty_line)")
    outf = summarise_frames( results, settings )
    println( outf )
    gl = add_gain_lose!( results.hh[1], results.hh[2], settings )
    println(sum(gl.gainers))
end 
=#

const INFO = """

* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Inequality an Poverty Measures](https://github.com/grahamstark/BudgetConstraints.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).
"""
"""
Plot two budget constraints (contained in dataframes) - legacy & universal credit.
"""
function plot1( 
	output :: NamedTuple )
	# legacy
	bl = scatter(
           lbc, 
		   x=:leisure, 
		   y=:net, 
           mode="line", 
		   name="Legacy Benefits", 
		   text=:simplelabel,
		   hoverinfo="text"
       )
	# uc
	gross_to_leisure!(ubc, wage )
	bu = scatter(
		ubc, 
		x=:leisure, 
		y=:net, 
		mode="line", 
		name="Universal Credit", 
		text=:simplelabel,
		hoverinfo="text"
		# ,xaxis="x2"
	)
	layout = Layout(
		title="Budget Constraint: Legacy Benefits vs Universal Credit",
        xaxis_title="Leisure (hours p.w.)",
        yaxis_title=ytitle,
		xaxis_range=[0, MAX_HRS ],
		yaxis_range=[0, 1_500],
		legend=attr(x=0.01, y=0.95),
		width=700, 
		height=700)
	p = PlotlyJS.plot( [bl, bu], layout)
	# (typeof(p))
	return p
end


"""
Create the block of sliders and radios on the LHS
"""
function get_input_block()
	return dbc_form([
		dbc_row([
			dbc_col(
				dbc_label("Basic Rate"; html_for="basic_rate"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "basic_rate",
					min = 0,
					max = 100,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:10:100]),
					value = 10.0,
					step = 1
				)), # col
		]),
		dbc_row([
			dbc_col([
				dbc_button(
					id = "submit-button", 
					class_name="primary", 
					color = "primary",
					name = "Run",
					value = "Run", 
					children = "submit"
					)
			]) # col
		]) # row
	]) # form
end 

app = dash(external_stylesheets=[dbc_themes.UNITED]) 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|
app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "You are Katie Forbes")
	html_h1("You are Katie Forbes"),
	dbc_row([
		dbc_col( dcc_markdown( PREAMBLE ), width=10)
	]), # row
	dbc_row([
    	dbc_col(get_input_block(), width=4),
		dbc_col([
			dcc_loading( 
				id="model_running", 
				type="default", 
				children = [
					html_div(
						id="loading-output-1"
						#= 
						children=(
							dcc_graph( id = "bc-1", figure=f1 )
						) # child graph
						=#
					) # div
				] # children
			) # loading
		]) # col
	]), # row
	
	dbc_row([
		dbc_col([
			dcc_graph( id = "bc-1" )])
	]),
	dbc_row([
		dbc_col( dcc_markdown( INFO ), width=10)
	]) # row
end # layout

function do_output( br )
	results = do_run( BASE_STATE.sys )
	plot( 1:10, results.summary.deciles[1][:,3], type=:bar )
end

callback!(
    app,
    Output("model_running",  "children"),
	Output("bc-1", "figure"),
	Input("submit-button", "n_clicks"),
	State( "basic_rate", "value")) do n_clicks, basic_rate
	println( "n_clicks = $n_clicks")
	if ! isnothing( n_clicks )
		return [nothing,do_output( basic_rate )]
	end
	[nothing,plot([1,2,3])]
end


run_server(app, "0.0.0.0", 8051; debug=true )