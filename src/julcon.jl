### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ 82cff020-f7c5-11ec-058b-adcf730aecd1
begin
	#
	# Load scotben
	#
	using Pkg
	Pkg.develop( url="https://github.com/grahamstark/ScottishTaxBenefitModel.jl")
	Pkg.add( "Plots")
	Pkg.add( "DataFrames")
	Pkg.add( "PlutoUI" )
	Pkg.add("Colors")
	Pkg.add("ColorVectorSpace")
	Pkg.add("ImageShow")
	Pkg.add("FileIO")
	Pkg.add("ImageIO")
	Pkg.add("BudgetConstraints")
	Pkg.add("SurveyDataWeighting")
	Pkg.add("PovertyAndInequalityMeasures")
	Pkg.add( "CSV" )
	Pkg.update()
end

# ╔═╡ 38953460-94b3-4a57-aee9-40dbc67b6b68
begin
    #
	# The Model 
	#	
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

	
	using Plots
	using PlutoUI
	using CSV
	using DataFrames
	#
	# Image stuff
	#
	using Colors, ColorVectorSpace, ImageShow, FileIO, ImageIO
	#
	# My stuff
	#
	using BudgetConstraints
	using SurveyDataWeighting
	using PovertyAndInequalityMeasures 
end

# ╔═╡ 47e47829-f21a-4473-b9f8-0f3f76fecaa8
begin
	PlutoUI.TableOfContents(aside=true)
end

# ╔═╡ c75e6664-dd0b-49e3-b085-7064314696c3
md"""

# ScotBen 
### A Microsimulation Tax Benefit Model for Scotland

Graham Stark [gks56@open.ac.uk](gks56@open.ac.uk)/[graham.stark@virtual-worlds.biz](graham.stark@virtual-worlds.biz)

[https://virtual-worlds.scot/ima2021/](https://virtual-worlds.scot/ima2021/)

"""

# ╔═╡ 64a59389-d29b-45b4-9958-a9aa89fbb5de
begin
	load( "/home/graham_s/julia/vw/Visualisations/web/images/tolleys_guides.jpeg")
end

# ╔═╡ 51a1df57-1d49-4267-af4a-b8569273bd3d
begin
	cpag = load( "/home/graham_s/julia/vw/Visualisations/web/images/cpag_guide.jpg" )
end

# ╔═╡ 6d54f8cc-025a-4693-8069-ee2e35048e77
begin
	cpay = load( "/home/graham_s/julia/vw/Visualisations/web/images/juliacon/bbc_scottish_child_payment.png" )
end

# ╔═╡ 4ddafeec-da63-43ad-95c7-25e0440d6b71
begin
	ni_inc = load( "/home/graham_s/julia/vw/Visualisations/web/images/juliacon/herald-national-insurance.png" )
end

# ╔═╡ b8ebf72d-3b12-485b-9f28-847cfa6f61b3
md"[The Model](https://github.com/grahamstark/ScottishTaxBenefitModel.jl)"

# ╔═╡ 402c1e02-3278-4678-b52f-295dfca4d99b
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

# ╔═╡ 871a6142-6ecc-4021-85fa-57189ffa1762
md"## Support Packages

* [Budget Constraints](https://github.com/grahamstark/BudgetConstraints.jl)
* [Survey Data Weighting](https://github.com/grahamstark/SurveyDataWeighting.jl)
* [Poverty and Inequality](https://github.com/grahamstark/PovertyAndInequalityMeasures.jl)

"

# ╔═╡ d879b6bf-768e-4dce-96fc-187792932380
md"""
## Data

* uses pooled (2015-2018) Scottish Households from [Family Resources Survey](https://www.gov.uk/government/collections/family-resources-survey--2) from the [UK Data Service](https://ukdataservice.ac.uk/);
* Data from the [Scottish Household Survey](https://www.gov.scot/collections/scottish-household-survey/) is [matched in](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/tree/master/matching). This allows much more accurate modelling of local taxes and (in the future) health, housing conditions;
* Since we have a [Calmar-like weighting system built-in](https://github.com/grahamstark/SurveyDataWeighting.jl), we can [weight to Scottish Population, Employment Levels, and so on](https://github.com/grahamstark/ScottishTaxBenefitModel.jl/blob/master/src/Weighting.jl) very accurately and easily.
"""


# ╔═╡ 335bdcce-014b-4c26-ba75-9c86ea5bb83a
begin
	settings2 = Settings()
	settings2
end

# ╔═╡ 911522b2-2f5f-4678-a324-8e765d026130

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

# ╔═╡ 5cd6bfaa-0d89-4e0c-843e-ea60ed297655
begin	
	hhs = CSV.File( "$(settings.data_dir)/model_households_scotland.tab" )|>DataFrame
	people = CSV.File( "$(settings.data_dir)/model_people_scotland.tab" )|>DataFrame
end

# ╔═╡ Cell order:
# ╠═82cff020-f7c5-11ec-058b-adcf730aecd1
# ╠═38953460-94b3-4a57-aee9-40dbc67b6b68
# ╠═47e47829-f21a-4473-b9f8-0f3f76fecaa8
# ╟─c75e6664-dd0b-49e3-b085-7064314696c3
# ╟─64a59389-d29b-45b4-9958-a9aa89fbb5de
# ╟─51a1df57-1d49-4267-af4a-b8569273bd3d
# ╟─6d54f8cc-025a-4693-8069-ee2e35048e77
# ╟─4ddafeec-da63-43ad-95c7-25e0440d6b71
# ╠═b8ebf72d-3b12-485b-9f28-847cfa6f61b3
# ╠═402c1e02-3278-4678-b52f-295dfca4d99b
# ╠═871a6142-6ecc-4021-85fa-57189ffa1762
# ╠═d879b6bf-768e-4dce-96fc-187792932380
# ╠═335bdcce-014b-4c26-ba75-9c86ea5bb83a
# ╠═911522b2-2f5f-4678-a324-8e765d026130
# ╠═5cd6bfaa-0d89-4e0c-843e-ea60ed297655
