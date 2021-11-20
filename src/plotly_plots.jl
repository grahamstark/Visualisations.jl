const TAB_RIGHT = Dict( "text-align"=>"right")
const TAB_LEFT = Dict( "text-align"=>"left")
const TAB_CENTRE = Dict( "text-align"=>"center")
const TAB_RED = Dict( "color"=>"#BB3311")
const TAB_GREEN = Dict( "color"=>"#33BB11")
const TAB_BOLD = Dict( "font-weight"=>"Bold")
    
    
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

function u( d ... )
    Dict( union(d...))
end

function draw_lorenz( pre::Vector, post::Vector )
    np = size(pre)[1]
    step = 1/np
    xr = 0:step:1
    # insert a zero element
    v1 = insert!(copy(pre),1,0)
    v2 = insert!(copy(post),1,0)
    
    layout = Layout(
        title="Lorenz Curve",
        xaxis_title="Population Share",
        yaxis_title="Net Income Share",
        xaxis_range=[0, 1],
        yaxis_range=[0, 1],
        legend=attr(x=0.01, y=0.95),
        width=350, 
        height=350)

    pre = scatter(
        x=xr, 
        y=v1, 
        mode="line", 
        name="Pre" )

    post = scatter(
        x=xr, 
        y=v2, 
        mode="line", 
        name="Post" )

    diag = scatter(y=[0,1], x=[0,1], showlegend=false, name="")   
    # return [pre, post, diag]
    #return Dict([:data=>[pre, post, diag],:layout=>layout])
    return PlotlyJS.Plot( [pre, post, diag], layout)
end

function drawDeciles( pre::Vector, post :: Vector )
    v = pre-post;
    layout = Layout(
        title="Gain/Loss by decile",
        xaxis_title="Decile",
        yaxis_title="£pw",
        width=350, 
        height=350)
    return PlotlyJS.Plot( bar( x=1:10, y=v), layout )
end

"""
There's a pre-computed histogram in summary, but
in turns out to be less hassle to just feed plotly
the raw data & let it do its own histogram.
"""
function drawMRS( pre :: DataFrame, post :: DataFrame )
    layout = Layout(
        title="Marginal Tax Rates",
        xaxis_title="METR(%)",
        yaxis_title="People",
        width=350, 
        height=350)
    preb = histogram( pre, x=:metr, y=0:5:200, histnorm="probability density")
    postb = histogram( post, x=:metr, y=0:5:200, histnorm="probability density")
    return PlotlyJS.Plot( [preb,postb], layout )
end

"""
This doesn't work well. 
"""
function drawMRS( pre :: Histogram, post :: Histogram )
    layout = Layout(
        title="Marginal Tax Rates",
        xaxis_title="METR(%)",
        yaxis_title="Number",
        width=350, 
        height=350)
    preb = bar( x=pre.edges, y=pre.weights)
    postb = bar( x=post.edges, y=post.weights)
    return PlotlyJS.Plot( [preb, postb], layout )
end

function thing_table( names::Vector{String}, v1::Vector, v2::Vector, up_is_good::Vector{Int} )
    table_header = 
        html_thead(
            html_tr([html_th(""), 
            html_th("Before",style=TAB_RIGHT),
            html_th("After",style=TAB_RIGHT),
            html_th("Change",style=TAB_RIGHT)])
        )
    rows = []
    n = size(names)[1]
    diff = v2 - v1
    for i in 1:n 
        colour = Dict()
        if (up_is_good[i] !== 0) && (! (diff[i] ≈ 0))
            if diff[i] > 0
                colour = up_is_good[i] == 1 ? TAB_GREEN : TAB_RED
             else
                colour = up_is_good[i] == 1 ? TAB_RED : TAB_GREEN
            end # neg diff   
        end # non zero diff
        ds = diff[i] ≈ 0 ? "-" : fp(diff[i])
        row = html_tr([html_td(names[i]), 
            html_td(f2(v1[i]),style=TAB_RIGHT),
            html_td(f2(v2[i]),style=TAB_RIGHT),
            html_td( ds ,style=u(TAB_RIGHT,colour))
            ])
        push!( rows, row )
    end
    table_body = html_tbody(rows)
    return dbc_table([table_header,table_body], bordered = false)
end 

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

const MR_UP_GOOD = [1,0,0,0,0,0,0,-1]

const COST_UP_GOOD = [1,1,1,1,-1,-1,-1,-1,-1,-1,-1]

function extract_incs( d :: DataFrame, targets :: Vector{Symbol}, row = 1 ) :: Vector
    n = length( targets )[1]
    out = zeros(n)
    for i in 1:n
        out[i] = d[row, targets[i]]
    end
    return out
end

function costs_table( incs1 :: DataFrame, incs2 :: DataFrame )
    v1 = extract_incs( incs1, COST_ITEMS ) ./ 1_000_000
    v2 = extract_incs( incs2, COST_ITEMS ) ./ 1_000_000
    thing_table( COST_LABELS, v1, v2, COST_UP_GOOD )
end

function frame_to_dash_table( 
    df :: DataFrame;
    up_is_good :: Vector{Int},
    prec :: Int = 2, 
    caption :: String = "" )
    table_header = 
        html_thead(
            html_tr([html_th(""), 
                html_th("Before",style=TAB_RIGHT),
                html_th("After",style=TAB_RIGHT),
                html_th("Change",style=TAB_RIGHT)
            ]) # tr
        )
    rows = []
    i = 0
    for r in eachrow( df )
        i += 1
        colour = Dict()
        if (up_is_good[i] !== 0) && (! (r.Change ≈ 0))
            if r.Change > 0
                colour = up_is_good[i] == 1 ? TAB_GREEN : TAB_RED
             else
                colour = up_is_good[i] == 1 ? TAB_RED : TAB_GREEN
            end # neg diff   
        end # non zero diff
        ds = r.Change ≈ 0 ? "-" : format(r.Change, commas=true, precision=prec )
        if ds != "-" && r.Change > 0
            ds = "+$(ds)"
        end 
        row = html_tr( [
            html_th( r.Item, style=TAB_LEFT),
            html_td(format(r.Before, commas=true, precision=prec),style=TAB_RIGHT),
            html_td(format(r.After, commas=true, precision=prec),style=TAB_RIGHT),
            html_td( ds, style=u(TAB_RIGHT,colour))])
        push!( rows, row )
    end
    table_body = html_tbody(rows)
    table_caption = caption != "" ? html_caption( caption ) : nothing 
    return dbc_table([table_header,table_caption,table_body], bordered = false)
end 

function costs_dataframe(  incs1 :: DataFrame, incs2 :: DataFrame ) :: DataFrame
    pre = extract_incs( incs1, COST_ITEMS ) ./ 1_000_000
    post = extract_incs( incs2, COST_ITEMS ) ./ 1_000_000
    diff = post-pre
    return DataFrame( Item=COST_LABELS, Before=pre, After=post, Change=diff )
end



function costs_table( incs1 :: DataFrame, incs2 :: DataFrame )
    df = costs_dataframe( incs1, incs2 )
    return frame_to_dash_table( df, prec=0, up_is_good=COST_UP_GOOD, caption="Costs and Revenues in £m pa, 2021/22" )
    # thing_table( COST_LABELS, v1, v2, COST_UP_GOOD )
end

function mr_dataframe( mr1::Histogram, mr2::Histogram )
    change = mr2.weights - mr1.weights
    DataFrame( Item=MR_LABELS, Before=mr1.weights, After=mr1.weights, Change=change)
end

function mr_table( mr1::Histogram, mr2::Histogram)
    df = mr_dataframe( mr1, mr2 )
    return frame_to_dash_table( 
        df, 
        prec=0, 
        up_is_good=MR_UP_GOOD, 
        caption="Working age individuals with Marginal Effective Tax Rates (METRs) in the given range." )
    # thing_table( MR_LABELS, mr1.weights, mr2.weights, MR_UP_GOOD)
end


function ineq_dataframe( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    names = ["Gini", "Palma", "Atkinson(ϵ=0.5)", "Atkinson(ϵ=1)", "Atkinson(ϵ=2)", "Hoover"]
    v1 = [ineq1.gini, ineq1.palma, ineq1.atkinson[2], ineq1.atkinson[4], ineq1.atkinson[8], ineq1.hoover] .* 100
    v2 = [ineq2.gini, ineq2.palma, ineq2.atkinson[2], ineq2.atkinson[4], ineq2.atkinson[8], ineq2.hoover] .* 100
    diff = v2 -v1
    return DataFrame( Item=names, Before=v1, After=v2, Change=diff)
end

function ineq_table( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    df = ineq_dataframe( ineq1, ineq2 )
    up_is_good = fill( -1, 6 )
    return frame_to_dash_table( 
        df, 
        prec=2, 
        up_is_good=up_is_good, 
        caption="Standard Inequality Measures" )
    #=
    names = ["Gini", "Palma", "Atkinson(ϵ=0.5)", "Atkinson(ϵ=1)", "Atkinson(ϵ=2)", "Hoover"]
    v1 = [ineq1.gini, ineq1.palma, ineq1.atkinson[2], ineq1.atkinson[4], ineq1.atkinson[8], ineq1.hoover] .* 100
    v2 = [ineq2.gini, ineq2.palma, ineq2.atkinson[2], ineq2.atkinson[4], ineq2.atkinson[8], ineq2.hoover] .* 100
    # 0.25, 0.50, 0.75, 1.0, 1.25, 1.50, 1.75, 2.0
    # 
    thing_table( names, v1, v2, up_is_good )
    =#
end

function pov_table( pov1 :: PovertyMeasures, pov2 :: PovertyMeasures )
    names = ["Headcount", "Gap", "FGT(α=2)", "Watts", "Sen", "Shorrocks"]
    v1 = [pov1.headcount, pov1.gap, pov1.foster_greer_thorndyke[5], pov1.watts, pov1.sen, pov1.shorrocks]  .* 100
    v2 = [pov2.headcount, pov2.gap, pov2.foster_greer_thorndyke[5], pov2.watts, pov2.sen, pov2.shorrocks]  .* 100
    up_is_good = fill( -1, 6 )
    # const DEFAULT_FGT_ALPHAS = [ 0.0, 0.50, 1.0, 1.50, 2.0, 2.5 ];
    thing_table( names, v1, v2, up_is_good )
end

function rb_table( sys :: TaxBenefitSystem )
    table_header_1 = 
        html_thead(
            html_tr([
                html_th("Rates(%)"),
                html_th("Threshold(£pa)")
	        ])
        )
    nr = size( sys.it.non_savings_rates)[1]
    rows = []
    
    rates = copy( sys.it.non_savings_rates ) .* 100
    bands = copy( sys.it.non_savings_thresholds ) .* WEEKS_PER_YEAR
    for i in 1:nr
        bs = (i < nr) ? f0(bands[i]) : "Remainder"
        row = html_tr([
            html_td(f2(rates[i]),style=TAB_RIGHT),
            html_td(bs,style=TAB_RIGHT)])
        push!( rows, row )
    end
    table_body = html_tbody(rows)
    table = dbc_table([table_header_1,table_body], bordered = false)
    println( typeof(table))
    return table
end

function make_output_table( results::NamedTuple, sys::TaxBenefitSystem )
    header = []    

    hrow_1 = html_tr([
        html_td(html_h4("Gainers and Losers"),style=TAB_CENTRE,colSpan=2),
		html_td(html_h4("Costs and Revenues (£m pa)"),style=TAB_CENTRE),
        html_td(html_h4("Incentives"),style=TAB_CENTRE)
	])

    row1 = html_tr([
        html_td(
			gain_lose_table( results.gain_lose)),
		html_td(dcc_graph(figure=drawDeciles( 
			results.summary.deciles[1][:,3],
			BASE_STATE.summary.deciles[1][:,3]))),
        html_td(
            costs_table(
                BASE_STATE.summary.income_summary[1],
                results.summary.income_summary[1])),
        html_td( 
            [
                
                mr_table( 
                    BASE_STATE.summary.metrs[1], 
                    results.summary.metrs[1] )
            ],style=TAB_CENTRE )
        ])

    hrow_2 = html_tr([
        html_td(html_h4("Poverty"),style=TAB_CENTRE),
		html_td(html_h4("Inequality"),style=TAB_CENTRE,colSpan=2)
	])
    
	row2 = html_tr([		
        html_td(
			pov_table(
				BASE_STATE.summary.poverty[1],
				results.summary.poverty[1])),
        html_td( ineq_table(
            BASE_STATE.summary.inequality[1],
            results.summary.inequality[1])),
        html_td( dcc_graph(figure=draw_lorenz(
                BASE_STATE.summary.deciles[1][:,2],
                results.summary.deciles[1][:,2]))),
        html_td() # spacer
    ]) # TR
    
    table_body = html_tbody([hrow_1, row1, hrow_2, row2 ]) #, row2 
    table = dbc_table([ table_body], bordered = false)
    
    return table
end

#=
function gain_lose_table_p( gl :: NamedTuple )
    lt = sum( gl.losers )
    gt = sum( gl.gainers )
    popn = sum( gl.popn )
    nct = sum( gl.nc )
    
    losers = md_format(lt)
    gainers = md_format(gt)
    nc = md_format(nct)

    losepct = md_format(100*lt/popn)
    gainpct = md_format(100*gt/popn)
    ncpct = md_format(100*nct/popn)

    tab = table(  
        # header_values=["", "", "%"],
        cells_values=[
            ["Gainers","No Change","Losers"],
            [gainers,nc,losers],
            ["($(gainpct)%)","($(ncpct)%)","($(losepct))"]
        ]
    )
    return PlotlyJS.plot( tab,
        Layout(width=200, height=300))
end
=#

function gain_lose_table( gl :: NamedTuple )
    losepct = md_format(100*gl.losers/gl.popn)
    gainpct = md_format(100*gl.gainers/gl.popn)
    ncpct = md_format(100*gl.nc/gl.popn)
    table_header = 
        html_thead(
            html_tr([html_th(""), html_th(""),html_th("%",style=TAB_RIGHT)])
        )
    row1 = html_tr([html_td("Gainers"), html_td(f0(gl.gainers),style=TAB_RIGHT),html_td(gainpct,style=TAB_RIGHT) ])
    row2 = html_tr([html_td("Losers"), html_td(f0(gl.losers),style=TAB_RIGHT),html_td(losepct,style=TAB_RIGHT)])
    row3 = html_tr([html_td("Unchanged"), html_td(f0(gl.nc),style=TAB_RIGHT),html_td(ncpct,style=TAB_RIGHT)])
    table_body = html_tbody([row1, row2, row3])
    table_caption = html_caption( "Individuals living in households where net income has risen, fallen, or stayed the same.")
    table = dbc_table([table_header,table_caption,table_body], bordered = false)
    return table
end