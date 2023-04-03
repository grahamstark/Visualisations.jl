
using Dash
using PlotlyJS
using DashBootstrapComponents

#
# NOT USED! ATTEMPT TO USE ALL-PLOTLY DASHBOARD
# 

#, DashHtmlComponents, DashCoreComponents

using Markdown
using DataFrames

include( "runner_libs.jl")
include( "dash_libs.jl")

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
	
	dbc_row([
		dbc_col([
			dcc_graph( id = "bc-1" )])
	]),
	dbc_row([
		dbc_col( dcc_markdown( INFO ), width=10)
	]) # row
end # layout

function do_output( br )
	br /= 100.0
	sys = deepcopy( BASE_STATE.sys )
	println("sys.it.non_savings_rates[2] $(sys.it.non_savings_rates[2])")
	incr = br-sys.it.non_savings_rates[2] 
	sys.it.non_savings_rates[1:3] .+= incr 
	results = do_run( sys )
	gls1 = gain_lose_table( 
		results.gain_lose )
	gls2 = gain_lose_table( 
		results.gain_lose )
	gls3 = gain_lose_table( 
		results.gain_lose )
	lorenz = draw_lorenz(
		BASE_STATE.summary.deciles[1][:,2],
		results.summary.deciles[1][:,2] )
	gbd = drawDeciles( 
		results.summary.deciles[1][:,4],
		BASE_STATE.summary.deciles[1][:,4] )

	fig = make_subplots(
		rows=3, 
		cols=3,	
		column_widths=[0.3, 0.3, 0.4],
		row_heights=[0.33, 0.33, 0.33],
		specs=[
			Spec(kind="xy")  Spec(kind="table", rowspan=1, colspan=1)  Spec(kind="xy");
			Spec(kind="xy")  Spec(kind="table", rowspan=1, colspan=1)  Spec(kind="xy");	
			Spec(kind="xy")  Spec(kind="xy")  Spec(kind="table", rowspan=1, colspan=1)]
	)
	for row in 1:3
		for col in 1:3
			if row > 1 && (row == col)
				add_trace!( fig, gls1, row=row, col=col)
			elseif row == 1 && col == 2
				add_trace!( fig, gls1, row=row, col=col)
			elseif rand(1:2) == 1
				add_trace!( fig, gbd, row=row, col=col )				
			else
				for i in lorenz
					add_trace!( fig, i, row=row, col=col )
				end
			end
		end
	end
		# specs=[
		#		Spec(kind="table") Spec(kind="xy")
		#
		#		missing Spec(kind= "scene")
		#
		#	]
		
		#
		

	return fig 
	
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
	[nothing,do_output(20)]
end


run_server(app, "0.0.0.0", 8051; debug=true )