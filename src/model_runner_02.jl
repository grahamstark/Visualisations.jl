
using Dash
using PlotlyJS
using DashBootstrapComponents
#, DashHtmlComponents, DashCoreComponents

using Markdown
using DataFrames

include( "run_and_consts.jl")
include( "plotly_plots.jl")

const FORM_EXTRA =Dict(
	"border-bottom"=>"1px dashed #aaaaaa", 
	"margin-bottom"=>"5px",
	"margin-top"=>"5px")

const PREAMBLE = """
"""



const INFO = """


* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Inequality an Poverty Measures](https://github.com/grahamstark/PovertyAndInequalityMeasures.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).
"""

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

function make_output_block( results )
    dbc_row([
        dbc_col(dcc_graph(figure=drawDeciles( 
			results.summary.deciles[1][:,3],
			BASE_STATE.summary.deciles[1][:,3]))),
        dbc_col(html_div(
			gain_lose_table( results.gain_lose))),
        dbc_col(html_div("One of three columns")),
    ]),
    dbc_row([
        dbc_col(html_div("One of two columns")),
        dbc_col( dcc_graph(figure=draw_lorenz(
			BASE_STATE.summary.deciles[1][:,2],
			results.summary.deciles[1][:,2] )
	)),
    ])
end

app = dash(external_stylesheets=[dbc_themes.UNITED]) 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|

app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "You are The Finance Minister")
	html_h1("You are The Finance Minister"),
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

	dbc_row( id="output-block" ), # results go here
	
	dbc_row([
		dbc_col( dcc_markdown( INFO ), width=10)
	]) # row
end # layout

function do_output( br )
	results = nothing
	if br != 20
		br /= 100.0
		sys = deepcopy( BASE_STATE.sys )
		println("sys.it.non_savings_rates[2] $(sys.it.non_savings_rates[2])")
		incr = br-sys.it.non_savings_rates[2] 
		sys.it.non_savings_rates[1:3] .+= incr 
		results = do_run( sys )
	else
		results = ( 
			summary = BASE_STATE.summary, 
			gain_lose = BASE_STATE.gain_lose )
	end
	return make_output_block(results)
end 


callback!(
    app,
    Output("model_running",  "children"),
	Output("output-block", "children"),
	Input("submit-button", "n_clicks"),
	State( "basic_rate", "value")) do n_clicks, basic_rate
	println( "n_clicks = $n_clicks")
	if ! isnothing( n_clicks )
		return [nothing,do_output( basic_rate )]
	end
	[nothing,do_output( 20 )]
end

run_server(app, "0.0.0.0", 8052; debug=true )