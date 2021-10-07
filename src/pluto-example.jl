### A Pluto.jl notebook ###
# v0.16.1

using Markdown
using InteractiveUtils

# ╔═╡ 8954681e-273b-11ec-344d-9326e736c69f
begin
	using Pkg
	
	Pkg.add( url="https://github.com/grahamstark/ScottishTaxBenefitModel.jl")
	using ScottishTaxBenefitModel
	
end

# ╔═╡ 0935685c-0d38-47fc-8f53-ff8aaa895f05
begin
	using Plots
	using .ExampleHouseholdGetter
	using .STBParameters
	using .BCCalcs
	using .Definitions
end

# ╔═╡ 6b4b41a4-2475-4d5d-8ea8-aef6d409c1e6
begin
	ExampleHouseholdGetter.initialise()
	hh = get_household("example_hh1")
	# MODEL_PARAMS_DIR
	sys21_22 = load_file( joinpath( MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	load_file!( sys21_22, joinpath( MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	# println( "weeklyise start wpm=$PWPM wpy=52")
	weeklyise!( sys21_22 )

	
end

# ╔═╡ Cell order:
# ╠═8954681e-273b-11ec-344d-9326e736c69f
# ╠═0935685c-0d38-47fc-8f53-ff8aaa895f05
# ╠═6b4b41a4-2475-4d5d-8ea8-aef6d409c1e6
