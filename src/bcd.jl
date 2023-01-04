
include( "uses.jl")

const FORM_EXTRA =Dict(
	"border-bottom"=>"1px dashed #aaaaaa", 
	"margin-bottom"=>"5px",
	"margin-top"=>"5px")

const PREAMBLE = """
Regardless of politics, I imagine most people an agree on the outlines of what
our taxation and benefit system should do. Give some support to people who haven't got much,
(depending who you ask, maybe take that support away from better off people); as you
get better off, pay a bit (or a lot) more in tax. But that's not always what the systems
we have do. Here's a simulation showing how the rules of the tax and benefit system 
interact to make it almost impossible for households to make sensible choices about
whether it's worth taking a job, working a bit more, or going for a promotion.  Using the
controls to the left, you can see from the charts how the choices between what you earn and what
you end up with vary for different family times (renting or owning, with and without children, high or low earners). 
"""

const INFO = """
The graph shows how net the net income of a household (i.e. after deducting taxes and optionally housing costs, then adding benefits)
varies with gross earnings, under the new [Universal Credit](https://www.gov.uk/universal-credit) 
benefit system and the
['legacy' Tax Credit system](https://www.gov.uk/topic/benefits-credits/tax-credits) which UC is gradually replacing. You can also switch to an 'economist's 
view' of the labour/leisure choice. Move your mouse over the chart to see a detailed
breakdown of what's happening at each point.

For simplicity, we assume:

* only one person in the household works;
* the adults are of working age;
* there are no other sources of income, for example savings income or disability benefits; 
* no student loans; and
* the working person faces a fixed hourly wage and can work any hours at that wage.

You'll see that the graphs are complicated enough even with those simplifications.
This is especially so for families with large housing costs
or several children, for whom the [Benefit Cap](https://www.gov.uk/benefit-cap) bites.


See [here](https://stb.virtual-worlds.scot/bc-intro.html) for more on the ideas behind budget constraints.

* Created with [Julia](https://julialang.org/) | [Dash](https://dash-julia.plotly.com/) | [Plotly](https://plotly.com/julia/) | [Budget Constraint Generator](https://github.com/grahamstark/BudgetConstraints.jl);
* Part of the [Scottish Tax Benefit Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl);	
* Open Source software released under the [MIT Licence](https://github.com/grahamstark/Visualisations.jl/blob/main/LICENSE). [Source Code](https://github.com/grahamstark/Visualisations.jl).
"""

"""
Generate a pair of budget constraints (as Dataframes) for the given household.
"""
function getbc( 
	hh  :: Household, 
	sys :: TaxBenefitSystem, 
	wage :: Real,
	settings :: Settings )::Tuple
	defroute = settings.means_tested_routing
	
	settings.means_tested_routing = lmt_full 
	lbc = BCCalcs.makebc( hh, sys, settings, wage )

	settings.means_tested_routing = uc_full 
	ubc = BCCalcs.makebc( hh, sys, settings, wage )

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
	w = MAX_HRS .- l
	# println(l)
	bc.leisure = l
	bc.ls = w
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
function econ_bcplot( lbc:: DataFrame, ubc :: DataFrame, wage :: Real, ytitle :: String )
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
	p = PlotlyJS.Plot( [bl, bu], layout)
	# (typeof(p))
	return p
end


"""
Plot two budget constraints (contained in dataframes) - legacy & universal credit.
"""
function bcplot( lbc:: DataFrame, ubc :: DataFrame, ytitle :: String )
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
	gn = scatter(y=[0,1500], x=[0,1500], showlegend=false, name="")

	gn["marker"] = Dict(:color => "#ccc",
                        :line => Dict(:color=> "#ccc",
                        :width=> 0.5))
	layout = Layout(
		title="Budget Constraint: Legacy Benefits vs Universal Credit",
        xaxis_title="Household Gross Earnings £p.w.",
        yaxis_title=ytitle,
		xaxis_range=[0, 1_200],
		yaxis_range=[0, 1_200],
		legend=attr(x=0.01, y=0.95),
		width=700, 
		height=700)
	p = PlotlyJS.Plot( [gn, bl, bu], layout)
	# (typeof(p))
	return p
end



function loadsystem(; ruk :: Bool )
	# FIXME TO CONSTANT use library version 
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2022-23.jl" ))
	if ruk 
		load_file!( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2022-23_ruk.jl" ))
	end
	# load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	weeklyise!( sys )
	return sys
end

const SCOTSYS = loadsystem(; ruk = false )
const UKSYS = loadsystem(; ruk = true )

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
	target_str :: AbstractString,
	taxsystem :: AbstractString )
	hh = get_hh( tenure, bedrooms, hcost, marrstat, chu5, ch5p )
	# println(to_md_table(hh))
	settings = Settings()
	ytitle = ""
	target = nothing
	if target_str == "ahc_hh" 
		target = ahc_hh 
		ytitle = "Household Net Income After Housing Costs £p.w."
	elseif target_str == "bhc_hh"
		target = bhc_hh 
		ytitle = "Household Net Income Before Housing Costs £p.w."
	elseif target_str == "total_bens" 
		ytitle = "Total State Benefits received £pw"
		target = total_bens 
	elseif target_str == "total_taxes"
		ytitle = "Total Income Tax and NI Payments £pw"
		target = total_taxes 
	end # forgot how to cover
	settings.target_bc_income = target
	sys = taxsystem == "scotland" ? SCOTSYS : RUKSYS
	lbc, ubc = getbc( hh, sys, wage, settings )
	if view == "l_vs_l"
		figure=econ_bcplot( lbc, ubc, wage, ytitle )
	else
		figure = bcplot( lbc, ubc, ytitle )
	end
	return figure 
end

"""
Create the block of sliders and radios on the LHS
"""
function get_input_block()
	return dbc_form(
		
		[
		dbc_row([
			dbc_col(
				dbc_label("Wage (£ per hour)"; html_for="wage"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "wage",
					min = 1,
					max = 40,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:10:100]),
					value = 10.0,
					step = 1
				)) # 
		], style=FORM_EXTRA),
		dbc_row([
			dbc_col(
				dbc_label("Tenure:"; html_for="tenure"), width=3
			),
			dbc_col(
				dbc_radioitems(
					id = "tenure",
					options = [(value = "owner", label= "Owner Occupier"),
					           (value = "private", label="Private Rented"),
							   (value = "council", label="Council/Housing Association")],
					value = "private"
				)
			)
		], style=FORM_EXTRA),
		dbc_row([
			dbc_col(
				dbc_label("Bedrooms:"; html_for="bedrooms"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "bedrooms",
					min = 1,
					max = 5,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 1:5]),
					value = 2,
					step = 1
    			)
			)
		], style=FORM_EXTRA), # row
		dbc_row([
			dbc_col(
				dbc_label("Housing Costs £pw:"; html_for="hcost"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "hcost",
					min = 0,
					max = 300,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:100:300]),
					value = 100,
					step = 1
    			)
			)
		], style=FORM_EXTRA), # row
		dbc_row([
			dbc_col(
				dbc_label("Adults:"; html_for="marrstat"), width=3
			),
			dbc_col(
				dbc_radioitems(
					id = "marrstat",
					options = [(value = "single", label= "Single"),
							   (value="couple", label="Couple")],
					value = "single"
				)
			)	
		], style=FORM_EXTRA), # row
		dbc_row([
			dbc_col(
				dbc_label("Children aged under 5:"; html_for="chu5"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "chu5",
					min = 0,
					max = 5,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:5]),
					value = 0,
					step = 1
    			)
			)
		], style=FORM_EXTRA),
		dbc_row([
			dbc_col(
				dbc_label("Children aged 5+:"; html_for="ch5p"), width=3
			),
			dbc_col(
				dcc_slider(
					id = "ch5p",
					min = 0,
					max = 8,
					marks = Dict([Symbol("$v") => Symbol("$v") for v in 0:8]),
					value = 0,
					step = 1
    			)
			)
		], style=FORM_EXTRA), # row
		dbc_row([
			dbc_col(
				dbc_label("Graph type:"; html_for="view"), width=3
			),
			dbc_col(
				dbc_radioitems(
					id = "view",
					options = [(value = "g_vs_n", label= "Gross vs Net Income"),
					           (value = "l_vs_l", label="Labour/Leisure")],
					value = "g_vs_n")
			)
		], style=FORM_EXTRA), # row
		dbc_row([
			dbc_col(
				dbc_label("Income Measure:"; html_for="target"), width=3
			),
			dbc_col(
				dbc_radioitems(
					id = "target",
					options = [(value = "ahc_hh", label= "After Housing Costs"),
					           (value = "bhc_hh", label= "Before Housing Costs"),
							   (value = "total_bens", label="Total Benefits Received"),
							   (value = "total_taxes", label="Total Taxes Paid") ],
					value = "ahc_hh")
			)
		], style=FORM_EXTRA),
		dbc_row([
			dbc_col(
				dbc_label("Which system to use:"; html_for="taxsystem"), width=3
			),
			dbc_col(
				dbc_radioitems(
					id = "taxsystem",
					options = [(value = "scotland", label= "Scottish System"),
					           (value = "ruk", label= "Rest of UK System") ],
					value = "scotland")
			)
		], style=FORM_EXTRA)
	])
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
				html_td(dcc_markdown(r.label)),
				html_td(dcc_markdown(r.label_p1))]
			)
		)
	end
    t = html_table([
        html_thead(html_tr([html_th("Gross"), html_th("Net"), html_th("Breakdown"), html_th("Breakdown+1p")])),
        html_tbody(rows)])
end

app = dash(external_stylesheets=[dbc_themes.UNITED], 
	url_base_pathname="/bcd/") 
# BOOTSTRAP|SIMPLEX|MINTY|COSMO|SANDSTONE|UNITED|SLATE|SOLAR|UNITED|
app.layout = dbc_container(fluid=true, className="p-5") do
	html_title( "Scotland's Kinkiest Families: Household Budget Constraints")
	html_h1("Scotland's Kinkiest Families: Household Budget Constraints"),
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
	# Input( "famchoice", "value"),
	Input( "wage", "value"),
	Input( "tenure", "value"),
	Input( "bedrooms", "value"),
	Input( "hcost", "value" ),
	Input( "marrstat", "value"),
	Input( "chu5", "value"),
	Input( "ch5p", "value"),
	Input( "view", "value"),
	Input( "scotland", "value")
	Input( "taxsystem", "value")) do wage, tenure, bedrooms, hcost, marrstat, chu5, ch5p, view, target, taxsystem
		return doplot( wage, tenure, bedrooms, hcost, marrstat, chu5, ch5p, view, target, taxsystem )
	end

run_server(app, "0.0.0.0", debug=true )
