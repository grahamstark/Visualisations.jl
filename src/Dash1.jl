
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

using DataFrames

app = dash()

function getbc( hh )
	# MODEL_PARAMS_DIR
	
	# head.age
	spouse = get_spouse(hh)
	head = get_head(hh)
	empty!( head.income )
	empty!( spouse.income )
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	# println( "weeklyise start wpm=$PWPM wpy=52")
	weeklyise!( sys )
	settings1 = Settings()
	settings2 = Settings()
	settings1.means_tested_routing = lmt_full 
	lbc = BCCalcs.makebc(hh, sys, settings1 )
	settings2.means_tested_routing = uc_full 
	ubc = BCCalcs.makebc(hh, sys, settings2 )
    (lbc,ubc)
end


function bcplot( lbc:: DataFrame, ubc :: DataFrame )
	bl = scatter(
           lbc, x=:gross, y=:net, 
           mode="line", name="Legacy"
       )
	bu = scatter(
		ubc, x=:gross, y=:net, 
		mode="line", name="UC"
	)
	layout = Layout(title="BC leg vs uc",
        xaxis_title="Gross",
        yaxis_title="Net")
	PlotlyJS.plot( [bl, bu], layout)
end



hhnames = ExampleHouseholdGetter.initialise()
d = []
for n in hhnames
	push!(d, Dict("label"=>String(n), "value" => String(n)))
	println(n)
end
hh = get_household("example_hh1")

lbc, ubc = getbc(hh)
app.layout = html_div() do
    html_h1("Hello Dash"),
    html_div("Dash: A web application framework for Julia"),
    
	html_label("Family"),
    dcc_dropdown(options = d, value = "example_hh1"),
   
	dcc_graph(
        id = "bc-1",
		figure=bcplot( lbc, ubc )
    )
end

run_server(app, "0.0.0.0", debug=true)
