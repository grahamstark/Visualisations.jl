
const COST_ITEMS = [
    :income_tax,
    :national_insurance,
    :employers_ni,
    :scottish_income_tax,

    :total_benefits,
    
    :means_tested_bens,
    :legacy_mtbs,
    :universal_credit,

    :non_means_tested_bens,
    :sickness_illness,
    :scottish_benefits] 

const COST_LABELS = [
    "Total Income Tax",
    "Employee's National Insurance",
    "Employer's National Insurance",
    "Scottish Income Tax",

    "Total Benefit Spending",

    "All Means Tested Benefits",
    "Legacy Means-Tested Benefits",
    "Universal Credit",

    "Non Means Tested Benefits",
    "Disability, Sickness-Related Benefits",
    "Scottish Benefits" ]

const MR_LABELS = 
    ["0 or negative", 
     "< 10.0%", 
     "10-20.0%", 
     "20-30.0%", 
     "30-50.0%", 
     "50-80.0%", 
     "80-100.0%", 
     "Above 100%"]


function f0( n :: Number ) :: String 
	format(n, commas=true, precision=0 )
	# , autoscale=:finance
end

function fp( n :: Number ) :: String 
	format(n, precision=2, signed=true )
	# , autoscale=:finance
end

function f2( n :: Number ) :: String 
	format(n, commas=true, precision=2 )
	# , autoscale=:finance
end


function costs_dataframe(  incs1 :: DataFrame, incs2 :: DataFrame ) :: DataFrame
    pre = extract_incs( incs1, COST_ITEMS ) ./ 1_000_000
    post = extract_incs( incs2, COST_ITEMS ) ./ 1_000_000
    diff = post-pre
    return DataFrame( Item=COST_LABELS, Before=pre, After=post, Change=diff )
end


function mr_dataframe( mr1::Histogram, mr2::Histogram )
    change = mr2.weights - mr1.weights
    DataFrame( Item=MR_LABELS, Before=mr1.weights, After=mr2.weights, Change=change)
end


function ineq_dataframe( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    names = ["Gini", "Palma", "Atkinson(ϵ=0.5)", "Atkinson(ϵ=1)", "Atkinson(ϵ=2)", "Hoover"]
    v1 = [ineq1.gini, ineq1.palma, ineq1.atkinson[2], ineq1.atkinson[4], ineq1.atkinson[8], ineq1.hoover] .* 100
    v2 = [ineq2.gini, ineq2.palma, ineq2.atkinson[2], ineq2.atkinson[4], ineq2.atkinson[8], ineq2.hoover] .* 100
    diff = v2 -v1
    return DataFrame( Item=names, Before=v1, After=v2, Change=diff)
end


function pov_dataframe( pov1 :: PovertyMeasures, pov2 :: PovertyMeasures )
    names = ["Headcount", "Gap", "FGT(α=2)", "Watts", "Sen", "Shorrocks"]
    v1 = [pov1.headcount, pov1.gap, pov1.foster_greer_thorndyke[5], pov1.watts, pov1.sen, pov1.shorrocks]  .* 100
    v2 = [pov2.headcount, pov2.gap, pov2.foster_greer_thorndyke[5], pov2.watts, pov2.sen, pov2.shorrocks]  .* 100
    diff = v2 - v1
    return DataFrame( Item=names, Before=v1, After=v2, Change=diff)
end



