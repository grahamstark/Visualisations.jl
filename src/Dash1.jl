
using Dash
# using DashHtmlComponents
# using DashCoreComponents
using PlotlyJS

#, DashHtmlComponents, DashCoreComponents
using ScottishTaxBenefitModel
using .BCCalcs
using .ModelHousehold
using .Utils
using .Definitions
using .SingleHouseholdCalculations
using .RunSettings
using .ExampleHouseholdGetter
using .STBParameters
using Markdown
using DataFrames

function getbc( 
	hh  :: Household, 
	sys :: TaxBenefitSystem, 
	settings :: Settings)::Tuple
	defroute = settings.means_tested_routing
	
	settings.means_tested_routing = lmt_full 
	lbc = BCCalcs.makebc( hh, sys, settings )

	settings.means_tested_routing = uc_full 
	ubc = BCCalcs.makebc( hh, sys, settings )

	settings.means_tested_routing = defroute
    (lbc,ubc)
end

function get_hh( name :: String )
	hh = get_household( name )
	head = get_head(hh)
	set_wage!( head, 0, 10 )
	spouse = get_spouse( hh )
	if spouse !== nothing
		set_wage!( spouse, 0, 10 )
	end
	for (pid,pers) in hh.people
		println( "age=$(pers.age) empstat=$(pers.employment_status) " )
		empty!( pers.income )
	end
	return hh
end

function bcplot( lbc:: DataFrame, ubc :: DataFrame )
	bl = scatter(
           lbc, 
		   x=:gross, 
		   y=:net, 
           mode="line", 
		   name="Legacy Benefits", 
		   text=:simplelabel,
		   hoverinfo="text"
       )
	# uc
	bu = scatter(
		ubc, 
		x=:gross, 
		y=:net, 
		mode="line", 
		name="Universal Credit", 
		text=:simplelabel,
		hoverinfo="text"
	)
	# 45% line
	gn = scatter(y=[0,1200], x=[0,1200], showlegend=false, name="")

	gn["marker"] = Dict(:color => "#ccc",
                        :line => Dict(:color=> "#ccc",
                        :width=> 0.5))
	layout = Layout(
		title="Budget Constraint: Legacy Benefits vs Universal Credit",
        xaxis_title="Person's Gross Earnings £p.w.",
        yaxis_title="Household Net Income After Housing Costs £p.w.",
		xaxis_range=[0, 1_200],
		yaxis_range=[0, 1_200],
		legend=attr(x=0.01, y=0.95),
		width=700, 
		height=700)
	p = PlotlyJS.plot( [gn, bl, bu], layout)
	println(typeof(p))
	p
end

function doplot( famname :: AbstractString )
	hh = get_hh( famname )
	settings = Settings()
	lbc, ubc = getbc(hh,sys,settings)
	figure=bcplot( lbc, ubc )
	return figure 
end

function generate_table(df :: DataFrame)
	rows = []
	for r in eachrow(df)
		push!(rows,
			html_tr([
				html_td(r.gross),
				html_td(r.net),
				html_td(dcc_markdown(r.label))]
			)
		)
	end
    t = html_table([
        html_thead(html_tr([html_th("Gross"), html_th("Net"), html_th("Breakdown")])),
        html_tbody(rows)])
end


hhnames = ExampleHouseholdGetter.initialise()
d = []
push!(d, Dict("label"=>"Couple, 2 children, Owner-Occupier.", "value" => "example_hh1"))
push!(d, Dict("label"=>"Lone Parent, 2 Children, £75pw rent.", "value" => "single_parent_1"))
push!(d, Dict("label"=>"Single Person £77.25pw rent.", "value" => "mel_c2"))


sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
# println( "weeklyise start wpm=$PWPM wpy=52")
weeklyise!( sys )

# app.layout = html_div() do

app = dash()
app.layout = html_div() do
		html_h1("BCs: Legacy vs UC Examples")
    	html_div(
			children = [
				html_h3( "col1"),
				html_label("Family"),
				dcc_dropdown(options = d, value = "example_hh1", id = "famchoice"),
				# generate_table( lbc ),
				dcc_markdown(
					"Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Budget Constraint Generator](https://github.com/grahamstark/BudgetConstraints.jl)"),
				dcc_markdown(
					"Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl)."),
				dcc_markdown(
					"This is Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl)")
				],
				style=(width="30%", display="inline-block")
			),
		html_div( 
			children = [
				dcc_graph(
					id = "bc-1" )
				],
				style=(width="69%", display="inline-block", float="right")
			)
end

callback!(
    app,
    Output("bc-1", "figure"),
	Input( "famchoice", "value")) do famname
		return doplot( famname )
	end


run_server(app, "0.0.0.0", debug=true)