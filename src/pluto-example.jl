### A Pluto.jl notebook ###
# v0.16.1

using Markdown
using InteractiveUtils

# ╔═╡ 8954681e-273b-11ec-344d-9326e736c69f
begin
	using Pkg
	
	Pkg.add( url="https://github.com/grahamstark/ScottishTaxBenefitModel.jl")
	using ScottishTaxBenefitModel
	using Plots
	
end

# ╔═╡ dd1d1115-41b3-4f3f-8cf9-6d97d944b9fa
begin
	using .ExampleHouseholdGetter
	using .STBParameters
	using .BCCalcs
	using .ModelHousehold
	using .Utils
	using .Definitions
	using .SingleHouseholdCalculations
	using .RunSettings
end

# ╔═╡ 6b4b41a4-2475-4d5d-8ea8-aef6d409c1e6
begin
	ExampleHouseholdGetter.initialise()
	hh = get_household("example_hh1")
	# MODEL_PARAMS_DIR
	
	# head.age
	spouse = get_spouse(hh)
	head = get_head(hh)
	empty!( head.income )
	empty!( spouse.income )
	hh
end

# ╔═╡ a68d4508-8749-41fa-ab49-157a18bc04fa
begin
	#	sys = TaxBenefitSystem{Float64}()
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	# println( "weeklyise start wpm=$PWPM wpy=52")
	weeklyise!( sys )


end

# ╔═╡ f32a80f9-37df-4a36-90f5-8f83f6e3551e
begin
	settings1 = Settings()
	settings2 = Settings()
	settings1.means_tested_routing = lmt_full 
	lbc = BCCalcs.makebc(hh, sys, settings1 )
	settings2.means_tested_routing = uc_full 
	ubc = BCCalcs.makebc(hh, sys, settings2 )
	
end

# ╔═╡ 49f2e5eb-71c1-48f0-909b-d85e2670e5f5
begin
	default(fontfamily="Gill Sans", 
		titlefont = (12,:grey), 
		legendfont = (9), 
		guidefont = (10), 
		tickfont = (9), 
		annotationfontsize=(8),
		annotationcolor=:blue		
	  )
	p1=plot( lbc[:,:gross], lbc[:,:net], label="legacy", widen=false, title="UC vs Legacy", ylims = (0,1200), xlims=(0,1200))
	plot!(p1, ubc[:,:gross], ubc[:,:net], label="UC")
end

# ╔═╡ 2108b252-cb89-434b-811a-f222be16bbf3
begin
	
	println( lbc[16:17, [:gross,:label]])
	println( lbc[16,:].label)
	println( lbc[17,:].label)
	head.income[wages]=484.797
	hres = do_one_calc( hh, sys, settings1 )
	hres.bus[1].pers[head.pid].it
	# head.income[wages]=484.797
	
end

# ╔═╡ Cell order:
# ╠═8954681e-273b-11ec-344d-9326e736c69f
# ╠═dd1d1115-41b3-4f3f-8cf9-6d97d944b9fa
# ╠═6b4b41a4-2475-4d5d-8ea8-aef6d409c1e6
# ╠═a68d4508-8749-41fa-ab49-157a18bc04fa
# ╠═f32a80f9-37df-4a36-90f5-8f83f6e3551e
# ╠═49f2e5eb-71c1-48f0-909b-d85e2670e5f5
# ╠═2108b252-cb89-434b-811a-f222be16bbf3
