
using Dash
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

app = dash()

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
	layout = Layout(title="Budget Constraint: Legacy Benefits vs Universal Credit",
        xaxis_title="Person's Gross Earnings £p.w.",
        yaxis_title="Household Net Income £p.w.",
		xaxis_range=[0, 1_200],
		yaxis_range=[0, 1_200],
		
		width=800, 
		height=650)
	p = PlotlyJS.plot( [gn, bl, bu], layout)
	println(typeof(p))
	p
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
push!(d, Dict("label"=>"Couple, 2 children", "value" => "example_hh1"))
push!(d, Dict("label"=>"Lone Parent, 2 Children", "value" => "single_parent_1"))
push!(d, Dict("label"=>"Single Person", "value" => "mel_c2"))



hh = get_household("example_hh1")
head = get_head(hh)
empty!( head.income )
spouse = get_spouse( hh )
if spouse !== nothing
	empty!( spouse.income )
end



sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
# println( "weeklyise start wpm=$PWPM wpy=52")
weeklyise!( sys )
settings = Settings()
lbc, ubc = getbc(hh,sys,settings)

# app.layout = html_div() do
app.layout = html_div(style = Dict("columnCount" => 2)) do

    html_h1("Budget Constraint Example"),
    html_div(""),
    
	html_label("Family"),
    dcc_dropdown(options = d, value = "example_hh1"),
    # generate_table( lbc ),
	dcc_graph(
        id = "bc-1",
		figure=bcplot( lbc, ubc )
    ),
	
	dcc_markdown(
	"Created with [Julia](https://julialang.org/) | 
	[Dash](https://dash-julia.plotly.com/) | 
	[Plotly](https://plotly.com/julia/) | 
	[Budget Constraint Generator](https://github.com/grahamstark/BudgetConstraints.jl)"),
	dcc_markdown(
		"Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl).
		"),
	dcc_markdown(
		"This is Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE).
		[Source Code](https://github.com/grahamstark/Visualisations.jl)"
	)

end

run_server(app, "0.0.0.0", debug=true)
