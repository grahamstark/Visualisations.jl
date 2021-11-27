### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# ╔═╡ 5b928827-1226-44f8-a295-0a5d072f3d9e
begin
	using Pkg
	Pkg.add(file="/home/graham_s/julia/vw/ScottishTaxBenefitModel" )

end

# ╔═╡ 6aace8e2-4efc-11ec-1460-d15ea3d01b48
begin
	using SurveyDataWeighting
	using BudgetConstraints
	using PovertyAndInequalityMeasures 
	using Plots,DataFrames,CSV
end

# ╔═╡ a0fa5a6f-16c7-4141-af1a-def84e31546e
begin
	using ScottishTaxBenefitModel
	
end

# ╔═╡ Cell order:
# ╠═6aace8e2-4efc-11ec-1460-d15ea3d01b48
# ╠═5b928827-1226-44f8-a295-0a5d072f3d9e
# ╠═a0fa5a6f-16c7-4141-af1a-def84e31546e
