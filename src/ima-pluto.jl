### A Pluto.jl notebook ###
# v0.17.2

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
	using Plots,CSV,DataFrames
end

# ╔═╡ b6b22dd4-bbb3-4c29-a27f-521cf14fc1d6
begin
	using ScottishTaxBenefitModel
	using .ExampleHouseholdGetter
	using .STBParameters
	using .BCCalcs
	using .ModelHousehold
	using .FRSHouseholdGetter
	using .Utils
	using .Definitions
	using .SingleHouseholdCalculations
	using .RunSettings
end

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
		  @time nhh, num_people,nhh2 = initialise( settings )
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

end


# ╔═╡ e8fa154d-e60b-407e-84ea-2b247141374d
begin
	ExampleHouseholdGetter.initialise(settings)
	nhhs,npeople = init_data()
end

# ╔═╡ b46666a3-3a24-485d-a1b6-41250fc21613
begin
hh = FRSHouseholdGetter.get_household(1)
for i in 1:nhhs
	hh =  FRSHouseholdGetter.get_household(i)
	
end
end

# ╔═╡ d10d14c7-2b1a-4dde-8ea4-e5c8dcd86887
begin
	hhs = CSV.File( "$(settings.data_dir)/model_households_scotland.tab" )|>DataFrame
	people = CSV.File( "$(settings.data_dir)/model_people_scotland.tab" )|>DataFrame
end

# ╔═╡ abc6d492-562f-4186-abf7-70aa825648fe


# ╔═╡ Cell order:
# ╠═53c06a7e-4f02-11ec-1109-65224850d083
# ╠═3dce1b1e-9756-48f2-a7dc-45363d1e3995
# ╠═b6b22dd4-bbb3-4c29-a27f-521cf14fc1d6
# ╠═9250ad90-8270-468c-9b51-87fc08451e08
# ╠═e8fa154d-e60b-407e-84ea-2b247141374d
# ╠═b46666a3-3a24-485d-a1b6-41250fc21613
# ╠═d10d14c7-2b1a-4dde-8ea4-e5c8dcd86887
# ╠═abc6d492-562f-4186-abf7-70aa825648fe
