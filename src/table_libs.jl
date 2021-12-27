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
    ["Negative or Zero",
     "Under 10%", 
     "10-20%", 
     "20-30%", 
     "30-50%", 
     "50-80%", 
     "80-100%", 
     "Above 100%"]


function extract_incs( d :: DataFrame, targets :: Vector{Symbol}, row = 1 ) :: Vector
    n = length( targets )[1]
    out = zeros(n)
    for i in 1:n
        out[i] = d[row, targets[i]]
    end
    return out
end
    
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

function mr_dataframe( mr1::Histogram, mr2::Histogram, mean1::Real, mean2 :: Real ) :: DataFrame
    println( "mr1.weights=$(mr1.weights) mean1=$mean1")
    change = mr2.weights - mr1.weights
    df = DataFrame( Item=MR_LABELS, Before=mr1.weights, After=mr2.weights, Change=change)
    mchange = mean2 - mean1
    push!( df, (Item="Average METR", Before=mean1, After=mean2, Change=mchange ))
    return df
end

function ineq_dataframe( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    names = ["Gini", "Palma", "Atkinson(ϵ=0.5)", "Atkinson(ϵ=1)", "Atkinson(ϵ=2)", "Hoover"]
    v1 = [ineq1.gini, ineq1.palma, ineq1.atkinson[2], ineq1.atkinson[4], ineq1.atkinson[8], ineq1.hoover] .* 100
    v2 = [ineq2.gini, ineq2.palma, ineq2.atkinson[2], ineq2.atkinson[4], ineq2.atkinson[8], ineq2.hoover] .* 100
    diff = v2 -v1
    return DataFrame( Item=names, Before=v1, After=v2, Change=diff)
end

function pov_dataframe( 
    pov1 :: PovertyMeasures, 
    pov2 :: PovertyMeasures, 
    ch1 :: GroupPoverty, 
    ch2 :: GroupPoverty )
    println( "got child poverty[1] as $(ch1)")            
    names = ["Headcount (All)", "Child Poverty", "Gap", "FGT(α=2)", "Watts", "Sen", "Shorrocks"]
    # child povs already %s ..
    v1 = [pov1.headcount, ch1.prop, pov1.gap, pov1.foster_greer_thorndyke[5], pov1.watts, pov1.sen, pov1.shorrocks]  .* 100
    v2 = [pov2.headcount, ch2.prop, pov2.gap, pov2.foster_greer_thorndyke[5], pov2.watts, pov2.sen, pov2.shorrocks]  .* 100
    diff = v2 - v1    
    return DataFrame( Item=names, Before=v1, After=v2, Change=diff)
end

function detailed_cost_dataframe( inc1 :: DataFrame, inc2 :: DataFrame )
    i1 = collect(values(inc1[1,1:98])) ./ 1_000_000
    c1 = collect(values(inc1[2,1:98]))
    i2 = collect(values(inc2[1,1:98])) ./ 1_000_000
    c2 = collect(values(inc2[2,1:98])) # fixme parameterise 98
    dc = c2 - c1
    di = i2 - i1
    names = pretty.(collect((keys(inc1[end,1:98]))))
    return  DataFrame( 
        :Item=>names, 
        :value1=>i1, 
        :count1=>c1,
        :value2=>i2, 
        :count2=>c2,
        :dval => di,
        :dcount => dc)
end