
using Dash
using PlotlyJS
using DashBootstrapComponents
#, DashHtmlComponents, DashCoreComponents
using ScottishTaxBenefitModel
using .BCCalcs
using .ModelHousehold
using .Utils
using .Definitions
using .SingleHouseholdCalculations
using .RunSettings
using .FRSHouseholdGetter
using .STBParameters
using .ExampleHelpers

using Markdown
using DataFrames

const FORM_EXTRA =Dict(
	"border-bottom"=>"1px dashed #aaaaaa", 
	"margin-bottom"=>"5px",
	"margin-top"=>"5px")

const PREAMBLE = """
"""


function calc_one_result( res :: DataFrane ) :: NamedTuple
	rc = @timed begin
		num_households,total_num_people,nhh2 = FRSHouseholdGetter.initialise( DEFAULT_SETTINGS )
		
	end
end

const 

const INFO = """

* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Budget Constraint Generator](https://github.com/grahamstark/BudgetConstraints.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).
"""
"""
Plot two budget constraints (contained in dataframes) - legacy & universal credit.
"""
function econ_bcplot( 
	lbc:: DataFrame, ubc :: DataFrame, wage :: Real, ytitle :: String )
	# legacy
	gross_to_leisure!(lbc, wage )
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
		#=
		xaxis2=attr(

            title="Hours of work", 
			# titlefont_color="blue",
            overlaying="x", 
			side="bottom", 
			position=0.15, 
			anchor="free"

        ),
		=#
		
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
	return dbc_form(
		
		[
		dbc_row([
			dbc_col(
				dbc_label("Basic Rate"; html_for="br"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "wage",
					min = 1,
					max = 50,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:10:100]),
					value = 10.0,
					step = 1
				)) # 
		], style=FORM_EXTRA),
			])
end 

sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
weeklyise!( sys )

app = dash(external_stylesheets=[dbc_themes.UNITED]) 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|
app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "You are Katie Forbes")
	html_h1("You are Katie Forbes"),
	dbc_row([
		dbc_col( dcc_markdown( PREAMBLE ), width=10)
	]),
	dbc_row([
    	dbc_col(get_input_block(), width=4),
	    dbc_col( dcc_graph( id = "bc-1" ))
		]
	),
	dbc_row([
		dbc_col( dcc_markdown( INFO ), width=10)
	])
	

end



callback!(
    app,
    Output("bc-1", "figure"),
	Input( "br", "value")) do br
		return doplot( br )
	end


run_server(app, "0.0.0.0", debug=true )

