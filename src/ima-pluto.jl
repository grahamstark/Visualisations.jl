### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ 53c06a7e-4f02-11ec-1109-65224850d083
begin
	using Pkg
	Pkg.add( url="/home/graham_s/julia/vw/ScottishTaxBenefitModel" )
end

# ╔═╡ 3dce1b1e-9756-48f2-a7dc-45363d1e3995
begin
	using BudgetConstraints
	using SurveyDataWeighting
	using PovertyAndInequalityMeasures
	using Plots,CSV,DataFrames,PlutoUI
	using PrettyTables
	using Observables
end

# ╔═╡ b6b22dd4-bbb3-4c29-a27f-521cf14fc1d6
begin
	using ScottishTaxBenefitModel
	import .ExampleHouseholdGetter
	using .STBParameters
	using .BCCalcs
	using .ModelHousehold
	import .FRSHouseholdGetter
	using .Utils
	using .Definitions
	using .SingleHouseholdCalculations
	using .RunSettings
	using .Monitor: Progress
end

# ╔═╡ 9ba57d28-9f19-43c6-b64b-79416ca8a12a
begin
	
	PlutoUI.TableOfContents(aside=true)
	
end

# ╔═╡ 7d0dcf51-deb9-4b74-98a8-e5e457e8e270
(PlutoUI.TableOfContents(aside=true))

# ╔═╡ 38beba12-681c-4d02-a247-8388e0b7df9b
md"""

# ScotBen 
### A Microsimulation Tax Benefit Model for Scotland

Graham Stark [gks56@open.ac.uk](gks56@open.ac.uk)/[graham.stark@virtual-worlds.biz](graham.stark@virtual-worlds.biz)

[https://virtual-worlds.scot/ima2021/](https://virtual-worlds.scot/ima2021/)

"""


# ╔═╡ 9250ad90-8270-468c-9b51-87fc08451e08


begin
	# housekeeping stuff
	const DEFAULT_NUM_TYPE = Float64
	settings = RunSettings.Settings()
	settings.requested_threads = 4
	settings.data_dir = "/home/graham_s/julia/vw/ScottishTaxBenefitModel/data"
	
	function init_data(; reset :: Bool = false )
	   nhh = FRSHouseholdGetter.get_num_households()
	   num_people = -1
	   if( nhh == 0 ) || reset 
		  @time nhh, num_people,nhh2 = FRSHouseholdGetter.initialise( settings )
	   end
	   (nhh,num_people)
	end
	

	function load_system()::TaxBenefitSystem
		sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
		#
		# Note that as of Budget21 removing these doesn't actually happen till May 2022.
		#
		load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
		# uc taper to 55
		load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "budget_2021_uc_changes.jl"))
		weeklyise!( sys )
		return sys
	end

md""" 
"""
	
end



# ╔═╡ e8fa154d-e60b-407e-84ea-2b247141374d
begin
	ExampleHouseholdGetter.initialise(settings)
	nhhs,npeople = init_data()
	md"  "
end

# ╔═╡ b46666a3-3a24-485d-a1b6-41250fc21613
begin
hh = FRSHouseholdGetter.get_household(1)
for i in 1:nhhs
	hh =  FRSHouseholdGetter.get_household(i)
	
end
end

# ╔═╡ 2917cd0f-2869-41f9-8b65-62cb75f3d278
md"""

## What?

Scotben is an open source microsimulation model tax-benefit of Scotland. Brand new - only brought to a useable state in the last fortnight. This is its first outing.

"""

# ╔═╡ ed1ca53b-0b7c-47e6-b4c8-9167731a49fb
md"""
## Why?

* Scottish Independence: the debate is about all sorts of things, but inevitably it's also about money: what would the budget of an independent Scotland look like?
* Scotland already has a measure of fiscal autonomy (most income tax, a few benefits, some enviromental taxes). What can be done with the powers we already have? 
* The standard of debate in Scotland (on all sides) is not high! This is my modest attempt to help;
* Scotland is sufficiently different from the rest of the UK (rUK) for a specialised model;
  - weight data specifically to Scottish demographics and uprate to Scotland-specific forecasts;
  - model the Scotland-specific taxes and benefits carefully.
* I was bored! This was my lockdown distraction. I'd been thinking about building this for several years, though;
* I know something about this: I worked for many years on the Institute for Fiscal Studies' TAXBEN, which was a good model in its day, and since then I've built [many different microsimulations](https://www.virtual-worlds.scot/demonstrations/) for clients all over the world.

"""

# ╔═╡ 067fd91d-77c6-436e-880b-45772b27d17a
md"""
## How?
* Conventional Tax Benefit Model - similar in outline to e.g. IFS Taxben and its descendants such as the, IPPR model;
* Highly modular design: it's made up of components that can easily be bolted  together to make e.g. forecasting models, social care simulations, etc.
* Static model - no non-takeup, labour supply etc. But get the structure right and these things are much easier;
* [Test first development](https://testing.googleblog.com/2007/01/introducing-testing-on-toilet.html) principle - write 'unit tests' describing how each tax and benefit should be calculated, and then just enough model code to make the tests pass - the [model test suite](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/test) is almost as big as the model itself.

"""

# ╔═╡ 0dfaf005-b39a-44c3-8b51-005feac8d78b
md"""
## Julia

* [Julia](https://julialang.org) bridges the gap between statistics packages and high-level programming languages;
* you can do detailed, accurate programming with good support for [rich types](https://docs.julialang.org/en/v1/manual/types/) (vital in a tax benefit model);
* but also use it for [data science/econometrics](https://juliastats.org/) (all the model regressions and graphics are native julia);
* *very* fast - [outpacing C/Fortran in some cases](https://julialang.org/benchmarks/);
* [Julia has a huge collection of contributed packages](https://juliahub.com) - including standard econometrics routines, data handling, graphics, differential equations and much else;
* This presentation is itself a Julia program, written using [Pluto](https://github.com/fonsp/Pluto.jl). The model and its data are actually loaded directly in to this presentation and we'll interact with them very briefly in a minute.
"""

# ╔═╡ 444b957f-0bcb-4703-9477-dcfcdc320ca6
md"""
## Open Source

* all the program code is available on [GitHub](https://github.com/grahamstark/ScottishTaxBenefitModel.jl) under a [permissive licence](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/LICENSE)
* I can't hide! Much harder to fudge things this way.

"""

# ╔═╡ 9512f4de-46ac-4f85-84c9-7a37ab391143
md"""
## Structure

Divided into [packages](https://julialang.org/packages/) and [modules](https://docs.julialang.org/en/v1/manual/modules/). A package is a high level generic chunk of code that can be downloaded and used independently. A module is a namespace - a small chunk of package code in which you can hide messy details from the rest of the program.

#### High Level generic packages:

These can be used directly in any model written in Julia. (And are fairly easy to port to [other](https://github.com/grahamstark/tax_benefit_model_components/blob/master/src/python/piecewise_linear_generator.py) [languages](https://github.com/grahamstark/tax_benefit_model_components/blob/master/src/python/weight_generator_tests.py)).

* [Budget Constraints](https://github.com/grahamstark/BudgetConstraints.jl);
* [Data Weighting](https://github.com/grahamstark/SurveyDataWeighting.jl);
* [Poverty & Inequality](https://github.com/grahamstark/PovertyAndInequalityMeasures.jl).

#### The Model

[The Model is itself a package](https://github.com/grahamstark/ScottishTaxBenefitModel.jl). Internally, it's broken down into a collection of semi-independent modules, for example: 

* [a household](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/ModelHousehold.jl);
* [the fiscal system parameters](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/STBParameters.jl);
* [means-tested benefits](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/LegacyMeansTestedBenefits.jl);
* [income tax](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/IncomeTaxCalculations.jl)

.. [and so on](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/src)

Some of the modules (e.g. [Equivalence Scales](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/EquivalenceScales.jl)) may eventually be moved out into generic packages.

"""

# ╔═╡ 2334e293-57f7-4b80-ad50-f889c8f6bab0
md"""
## Data

* uses pooled (2015-2018) Scottish Households from [Family Resources Survey](https://www.gov.uk/government/collections/family-resources-survey--2) from the [UK Data Service](https://ukdataservice.ac.uk/);
* Data from the [Scottish Household Survey](https://www.gov.scot/collections/scottish-household-survey/) is [matched in](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/matching). This allows much more accurate modelling of local taxes and (in the future) health, housing conditions;
* Since we have a [Calmar-like weighting system built-in](https://github.com/grahamstark/SurveyDataWeighting.jl), we can [weight to Scottish Population, Employment Levels, and so on](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/Weighting.jl) very accurately and easily.
"""

# ╔═╡ d10d14c7-2b1a-4dde-8ea4-e5c8dcd86887
begin	
	hhs = CSV.File( "$(settings.data_dir)/model_households_scotland.tab" )|>DataFrame
	people = CSV.File( "$(settings.data_dir)/model_people_scotland.tab" )|>DataFrame
end

# ╔═╡ abc6d492-562f-4186-abf7-70aa825648fe
md"""
## The Model In Action

No point if people can't use it. I've no plans to build a full web UI. [Been there, done that, boring and rarely used](https://www.virtual-worlds.scot/demonstrations/). 

Instead, simple single-page UIs illustrating one point of interest. So far:

* [Budget Constraints](https://stb.virtual-worlds.scot/bcd/) - the weird, kinky world of the UK Tax Benefit System
* [A Simple Budget For Scotland](https://stb.virtual-worlds.scot/scotbudg/)

[These visualisations]() use [Dash](https://dash-julia.plotly.com/). 

For full detailed interactions, this Pluto notebook system and 'lab assistant' programs such as [Dr Watson](https://juliadynamics.github.io/DrWatson.jl/dev/).

"""

# ╔═╡ 43eaea11-1764-4dee-af79-05aa264937c4
md"""

## Known Problems

This is a very new model and full results are just emerging over the last 2 weeks. The test suite gives me confidence that the low-level calculations are accurate. However:

* Modelled [Inequality is too low](https://data.gov.scot/poverty/) compared to official figures - possibly related to 100% takeup
* Revenue estimates for Income Tax ~£1bn too high compared to [official forecasts](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/):
  - possibly employers pension contributions;
  - or something to do with the pandemic.

"""

# ╔═╡ 47148425-e812-4ec3-ab40-49603b5d53ee
md"""

## Next Steps

Scotben's clean interfaces and modular structure makes adding features easy. Julia also working as a statistics package makes adding behavioural features much easier.

* [Benefit non-takeup corrections](https://ifs.org.uk/publications/1954)  - this seems important for e.g. inequality estimates;
* long term projections (e.g. the [Scottish Growth Commission](https://www.sustainablegrowthcommission.scot/)- long term projection is technically quite easy with the components we have. [An earlier exercise is available](https://github.com/grahamstark/scottish_child_poverty_projections);
* consumption and spending data - either using estimated Engel Curves or matching in [Living Costs and Food Survey](https://www.ons.gov.uk/peoplepopulationandcommunity/personalandhouseholdfinances/incomeandwealth/methodologies/livingcostsandfoodsurvey) (LCF) data.

And much else.

"""

# ╔═╡ 285cdbf5-1e73-428a-bc1d-88ea8a731ce0
md"""
## To Find Out More

* **Tax Benefit Models**: [A short introduction to microsimulation and tax benefit models](https://stb.virtual-worlds.scot/intro.html). Originally written for the Open University, it covers all the essential ideas. | I've also written [the most boring blog ever about the Model](https://stb-blog.virtual-worlds.scot/);

* **Poverty and Inequality**: [My Notes](https://stb.virtual-worlds.scot/poverty.html) | [World Bank Handbook](http://documents.worldbank.org/curated/en/488081468157174849/Handbook-on-poverty-and-inequality) | [Official Figures for Scotland](https://data.gov.scot/poverty/);

* **Scotland's Finances**: [Scottish Fiscal Commission](https://www.fiscalcommission.scot/publications/scotlands-economic-and-fiscal-forecasts-august-2021/) | [Scottish Government Budget Documents](https://www.gov.scot/budget/).

I'd very much welcome contributions and suggestions. If you spot anything odd or if you have any ideas for how this can be improved, you can:

* [Open an issue on GitHub](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/issues); or
* [email me](mailto:graham.stark@virtual-worlds.biz).

finally, you can download this presentation from [https://virtual-worlds.scot/ima2021/pres.zip](https://virtual-worlds.scot/ima2021/pres.zip)

"""

# ╔═╡ ed11b677-72dc-448e-970e-a2b1d871b360
begin
	tot = 0	
	# observer = Observer(Progress("",0,0,0))
	obs = Observable( Monitor.Progress(settings.uuid,"",0,0,0,0))
	of = on(obs) do p
	    global tot
	    # println(p)	
	    tot += p.step
	    # println(tot)
	end
end

# ╔═╡ 6a023861-c224-46ff-83b5-38e49aee7ecb

function basic_run( ; print_test :: Bool, mtrouting :: MT_Routing )
    settings.means_tested_routing = mtrouting
    settings.run_name="run-$(mtrouting)-$(date_string())"
    sys = [get_system(scotland=false), get_system( scotland=true )]
    tot = 0
    results = do_one_run( settings, sys, obs )
    h1 = results.hh[1]
    pretty_table( h1[:,[:weighted_people,:bhc_net_income,:eq_bhc_net_income,:ahc_net_income,:eq_ahc_net_income]] )
end 



# ╔═╡ 3483fe7d-2f91-4a44-bdfa-2d2cee3bfc44
begin
	basic_run( print_test=true, mtrouting = mt )
end

# ╔═╡ Cell order:
# ╠═53c06a7e-4f02-11ec-1109-65224850d083
# ╠═3dce1b1e-9756-48f2-a7dc-45363d1e3995
# ╠═b6b22dd4-bbb3-4c29-a27f-521cf14fc1d6
# ╟─9ba57d28-9f19-43c6-b64b-79416ca8a12a
# ╟─7d0dcf51-deb9-4b74-98a8-e5e457e8e270
# ╟─38beba12-681c-4d02-a247-8388e0b7df9b
# ╟─9250ad90-8270-468c-9b51-87fc08451e08
# ╟─e8fa154d-e60b-407e-84ea-2b247141374d
# ╟─b46666a3-3a24-485d-a1b6-41250fc21613
# ╟─2917cd0f-2869-41f9-8b65-62cb75f3d278
# ╟─ed1ca53b-0b7c-47e6-b4c8-9167731a49fb
# ╟─067fd91d-77c6-436e-880b-45772b27d17a
# ╟─0dfaf005-b39a-44c3-8b51-005feac8d78b
# ╟─444b957f-0bcb-4703-9477-dcfcdc320ca6
# ╟─9512f4de-46ac-4f85-84c9-7a37ab391143
# ╟─2334e293-57f7-4b80-ad50-f889c8f6bab0
# ╠═d10d14c7-2b1a-4dde-8ea4-e5c8dcd86887
# ╟─abc6d492-562f-4186-abf7-70aa825648fe
# ╟─43eaea11-1764-4dee-af79-05aa264937c4
# ╟─47148425-e812-4ec3-ab40-49603b5d53ee
# ╟─285cdbf5-1e73-428a-bc1d-88ea8a731ce0
# ╠═ed11b677-72dc-448e-970e-a2b1d871b360
# ╠═6a023861-c224-46ff-83b5-38e49aee7ecb
# ╠═3483fe7d-2f91-4a44-bdfa-2d2cee3bfc44
