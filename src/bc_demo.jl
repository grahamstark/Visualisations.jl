
using Dash
using PlotlyJS
# using DashBootstrapComponents
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
using .ExampleHelpers
using Markdown
using DataFrames

"""
Generate a pair of budget constraints (as Dataframes) for the given household.
"""
function getbc( 
	hh  :: Household, 
	sys :: TaxBenefitSystem, 
	wage :: Real,
	settings :: Settings,
	target :: TargetIncomes )::Tuple
	defroute = settings.means_tested_routing
	
	settings.means_tested_routing = lmt_full 
	lbc = BCCalcs.makebc( hh, sys, settings, wage, target )

	settings.means_tested_routing = uc_full 
	ubc = BCCalcs.makebc( hh, sys, settings, wage, target )

	settings.means_tested_routing = defroute
    (lbc,ubc)
end

"""
Retrieve one of the model's example households & overwrite a few fields
to make things simpler.
"""
function get_hh( 
	tenure    :: AbstractString,
	bedrooms  :: Integer, 
	hcost     :: Real, 
	marrstat    :: AbstractString, 
	chu5      :: Integer, 
	ch5p      :: Integer ) :: Household
	hh = get_example( single_hh )
	head = get_head(hh)
	head.age = 30
	sp = get_spouse(hh)
	enable!(head) # clear dla stuff from example
	hh.tenure = if tenure == "private"
		Private_Rented_Unfurnished
	elseif tenure == "council"
		Council_Rented
	elseif tenure == "owner"
		Mortgaged_Or_Shared
	else
		@assert false "$tenure not recognised"
	end
	hh.bedrooms = bedrooms
	hh.other_housing_charges = hh.water_and_sewerage = 0
	if hh.tenure == Mortgaged_Or_Shared
		hh.mortgage_payment = hcost
		hh.mortgage_interest = hcost
		hh.gross_rent = 0
	else
		hh.mortgage_payment = 0
		hh.mortgage_interest = 0
		hh.gross_rent = hcost
	end
	if marrstat == "couple"
		sex = head.sex == Male ? Female : Male # hetero ..
		add_spouse!( hh, 30, sex )
		sp = get_spouse(hh)
		enable!(sp)
		set_wage!( sp, 0, 10 )
	end
	age = 0
	for ch in 1:chu5
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	age = 7
	for ch in 1:ch5p
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	set_wage!( head, 0, 10 )
	for (pid,pers) in hh.people
		# println( "age=$(pers.age) empstat=$(pers.employment_status) " )
		empty!( pers.income )
		empty!( pers.assets )
	end
	return hh
end

const MAX_HRS = 80

function gross_to_leisure!( bc :: DataFrame, wage::Real)
	gross = bc[:,:gross]
	l = MAX_HRS .- (gross ./ wage)
	# println(l)
	bc.leisure = l
	# some nice way
	p = 0
	for r in eachrow(bc)
		p += 1
		if r.leisure < 0
			break 
		end
	end
	bc = bc[1:p,:]
end

"""
Plot two budget constraints (contained in dataframes) - legacy & universal credit.
"""
function econ_bcplot( lbc:: DataFrame, ubc :: DataFrame, wage :: Real )
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
	)

	#= 45% line
	gn = scatter(y=[0,1200], x=[0,120], showlegend=false, name="")

	gn["marker"] = Dict(:color => "#ccc",
                        :line => Dict(:color=> "#ccc",
                        :width=> 0.5))
	=#
	layout = Layout(
		title="Budget Constraint: Legacy Benefits vs Universal Credit",
        xaxis_title="Leisure (hours p.w.)",
        yaxis_title="Household Net Income After Housing Costs £p.w.",
		xaxis_range=[0, MAX_HRS ],
		yaxis_range=[0, 1_200],
		legend=attr(x=0.01, y=0.95),
		width=700, 
		height=700)
	p = PlotlyJS.plot( [bl, bu], layout)
	# (typeof(p))
	return p
end


"""
Plot two budget constraints (contained in dataframes) - legacy & universal credit.
"""
function bcplot( lbc:: DataFrame, ubc :: DataFrame )
	# legacy
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
	# (typeof(p))
	return p
end

"""
Create the whole plot for the named household. 
"""
function doplot( 
	wage :: Real,
	tenure :: AbstractString,
	bedrooms::Integer, 
	hcost::Real, 
	marrstat::AbstractString, 
	chu5::Integer, 
	ch5p::Integer,
	view :: AbstractString,
	target_str :: AbstractString )
	hh = get_hh( tenure, bedrooms, hcost, marrstat, chu5, ch5p )
	# println(to_md_table(hh))
	settings = Settings()
	target = if target_str == "ahc_hh" 
		 ahc_hh 
		elseif target_str == "bhc_hh"
			bhc_hh 
		elseif target_str == "total_bens" 
			total_bens 
		elseif target_str == "total_taxes"
			total_taxes 
		end # forgot how to covert
	lbc, ubc = getbc( hh, sys, wage, settings, target )
	if view == "l_vs_l"
		figure=econ_bcplot( lbc, ubc, wage )
	else
		figure = bcplot( lbc, ubc )
	end
	return figure 
end

"""
an experimental html table. Not actually used.
"""
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

# not used either
hhnames = ExampleHouseholdGetter.initialise()
d = []
push!(d, Dict("label"=>"Couple 28, 29; 2 children; £80pw mortgage.", "value" => "example_hh1"))
push!(d, Dict("label"=>"Lone Parent, age 30; 2 Children; £103pw rent.", "value" => "single_parent_1"))
push!(d, Dict("label"=>"Single Person, Age 21; £103pw rent.", "value" => "mel_c2"))



sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
weeklyise!( sys )

app = dash(external_stylesheets= [])
app.layout = html_div() do
		html_h1("Household Budget Constraints: Legacy vs UC Examples"),
    	html_div(
			children = [
				html_label("Hourly Wage:"; htmlFor="wage"),
				dcc_slider(
					id = "wage",
					min = 1,
					max = 40,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:10:100]),
					value = 10.0,
					step = 1
    			),
				html_label("Tenure:"; htmlFor="tenure"),
				dcc_radioitems(
					id = "tenure",
					options = [(value = "owner", label= "Owner Occupier"),
					           (value = "private", label="Private Rented"),
							   (value = "council", label="Council/HA")],
					value = "private",
					labelStyle=Dict("display" => "list")
				),
				html_label("Bedrooms:"; htmlFor="bedrooms"),
				dcc_slider(
					id = "bedrooms",
					min = 1,
					max = 5,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 1:5]),
					value = 2,
					step = 1
    			),
				html_label("Housing Costs £pw:"; htmlFor="hcost"),
				dcc_slider(
					id = "hcost",
					min = 0,
					max = 300,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:100:300]),
					value = 100,
					step = 1
    			),				
				html_label("Adults:"; htmlFor="marrstat"),
				dcc_radioitems(
					id = "marrstat",
					options = [(value = "single", label= "Single"),
							   (value="couple", label="Couple")],
					value = "single",
					labelStyle=Dict("display" => "list")
				),
				html_label("Children aged under 5:"; htmlFor="chu5"),
				dcc_slider(
					id = "chu5",
					min = 0,
					max = 5,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:5]),
					value = 0,
					step = 1
    			),
				html_label("Children aged 5+:"; htmlFor="ch5p"),
				dcc_slider(
					id = "ch5p",
					min = 0,
					max = 8,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:8]),
					value = 0,
					step = 1
    			),
				html_label("View:"; htmlFor="view"),
				dcc_radioitems(
					id = "view",
					options = [(value = "g_vs_n", label= "Gross vs Net Income"),
					           (value = "l_vs_l", label="Labour/Leisure")],
					value = "g_vs_n",
					labelStyle=Dict("display" => "list")
				),
				html_label("Income Measure:"; htmlFor="target"),
				dcc_radioitems(
					id = "target",
					options = [(value = "ahc_hh", label= "After Housing Costs"),
					           (value = "bhc_hh", label= "Before Housing Costs"),
							   (value = "total_bens", label="Total Benefits Received"),
							   (value = "total_taxes", label="Total Taxes Paid") ],
					value = "ahc_hh",
					labelStyle=Dict("display" => "list")
				),
				dcc_markdown(
	"""
This illustrates how net the net income of a household (i.e. after deducting taxes and housing costs, then adding benefits)
varies with gross earnings, under the new Universal Credit benefit system and the old
'legacy' tax-credit system. 

For simplicity, we assume:

* only one person in the household works;
* there are no other sources of income;
* the working person faces a fixed £10 hourly wage and can work any hours at that wage.

You'll see that the graphs are complicated enough even with those simplifications.

Choose one of the three example families above. Move your mouse over the 'kink points' in the graph for a detailed calculation.

See [here](https://stb.virtual-worlds.scot/bc-intro.html) for more on the ideas behind budget constraints.

* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Budget Constraint Generator](https://github.com/grahamstark/BudgetConstraints.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).
	"""	)
	],
				style=(width="30%", display="inline-block")
			),
		html_div( 
			children = [dcc_graph( id = "bc-1" )],
				style=(width="69%", display="inline-block", float="right")
			)
end

callback!(
    app,
    Output("bc-1", "figure"),
	# Input( "famchoice", "value"),
	Input( "wage", "value"),
	Input( "tenure", "value"),
	Input( "bedrooms", "value"),
	Input( "hcost", "value" ),
	Input( "marrstat", "value"),
	Input( "chu5", "value"),
	Input( "ch5p", "value"),
	Input( "view", "value"),
	Input( "target", "value")) do wage, tenure, bedrooms, hcost, marrstat, chu5, ch5p, view, target
		return doplot( wage, tenure, bedrooms, hcost, marrstat, chu5, ch5p, view, target )
	end


run_server(app, "0.0.0.0", debug=true)