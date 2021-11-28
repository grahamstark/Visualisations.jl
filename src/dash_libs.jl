const TAB_RIGHT = Dict( "text-align"=>"right")
const TAB_LEFT = Dict( "text-align"=>"left")
const TAB_CENTRE = Dict( "text-align"=>"center")
const TAB_RED = Dict( "color"=>"#BB3311")
const TAB_GREEN = Dict( "color"=>"#33BB11")
const TAB_BOLD = Dict( "font-weight"=>"Bold")
const TAB_TOTAL = Dict( "font-weight"=>"Bold", "background-color"=>"#ccccee" )
const RESERVED = Dict( "background-color"=>"#dddddd")
    
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
    println( "v=$v")
    layout = Layout(
        title="Gain/Loss by decile",
        xaxis_title="Decile",
        yaxis_title="£pw",
        width=350, 
        height=350)
    return PlotlyJS.Plot( bar( x=1:11, y=v), layout )
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
const MR_UP_GOOD = [1,0,0,0,0,0,0,-1,1]

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
    caption :: String = "",
    totals_col :: Int = -1 )
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
        row_style = i == totals_col ? TAB_TOTAL : Dict()
        row = html_tr( [
            html_th( r.Item, style=TAB_LEFT),
            html_td(format(r.Before, commas=true, precision=prec),style=TAB_RIGHT),
            html_td(format(r.After, commas=true, precision=prec),style=TAB_RIGHT),
            html_td( ds, style=u(TAB_RIGHT,colour))], style=row_style)
        push!( rows, row )
    end
    table_body = html_tbody(rows)
    table_caption = caption != "" ? html_caption( caption ) : nothing 
    return dbc_table([table_header,table_caption,table_body], bordered = false)
end 


function costs_table( incs1 :: DataFrame, incs2 :: DataFrame )
    df = costs_dataframe( incs1, incs2 )
    return frame_to_dash_table( df, prec=0, up_is_good=COST_UP_GOOD, 
        caption="Tax Liabilities and Benefit Entitlements, £m pa, 2021/22" )
    # thing_table( COST_LABELS, v1, v2, COST_UP_GOOD )
end

function mr_table( mr1, mr2 )
    df = mr_dataframe( mr1.hist, mr2.hist, mr1.mean, mr2.mean )
    n = size(df)[1]
    table = frame_to_dash_table( 
        df, 
        prec=0, 
        up_is_good=MR_UP_GOOD, 
        caption="Working age individuals with Marginal Effective Tax Rates
                (METRs) in the given range. METR is the percentage of the next £1 you earn that is taken away in taxes or 
                reduced means-tested benefits.",
        totals_col = n )   
    return table

    # thing_table( MR_LABELS, mr1.weights, mr2.weights, MR_UP_GOOD)
end


function ineq_table( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    df = ineq_dataframe( ineq1, ineq2 )
    up_is_good = fill( -1, 6 )
    return frame_to_dash_table( 
        df, 
        prec=2, 
        up_is_good=up_is_good, 
        caption="Standard Inequality Measures." )
end

function pov_table( pov1 :: PovertyMeasures, pov2 :: PovertyMeasures )
    df = pov_dataframe( pov1, pov2 )
    up_is_good = fill( -1, 6 )
    return frame_to_dash_table( 
        df, 
        prec=2, 
        up_is_good=up_is_good, 
        caption="Standard Poverty Measures." )
end


function gain_lose_table( gl :: NamedTuple )
    losepct = md_format(100*gl.losers/gl.popn)
    gainpct = md_format(100*gl.gainers/gl.popn)
    ncpct = md_format(100*gl.nc/gl.popn)
    table_header = 
        html_thead(
            html_tr([html_th(""), html_th(""),html_th("%",style=TAB_RIGHT)])
        )
    row1 = html_tr([html_th("Gainers"), html_td(f0(gl.gainers),style=TAB_RIGHT),html_td(gainpct,style=TAB_RIGHT) ])
    row2 = html_tr([html_th("Losers"), html_td(f0(gl.losers),style=TAB_RIGHT),html_td(losepct,style=TAB_RIGHT)])
    row3 = html_tr([html_th("Unchanged"), html_td(f0(gl.nc),style=TAB_RIGHT),html_td(ncpct,style=TAB_RIGHT)])
    table_body = html_tbody([row1, row2, row3])
    table_caption = html_caption( "Individuals living in households where net income has risen, fallen, or stayed the same respectively.")
    table = dbc_table([table_header,table_caption,table_body], bordered = false)
    return table
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

# as an actual table
function make_output_table_t( results::NamedTuple, sys::TaxBenefitSystem )
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

# as bootstrap rows
function make_output_table( results::NamedTuple, sys::TaxBenefitSystem )
    row1 = dbc_row([
        dbc_col([
            html_h4("Gainers and Losers"),
            dbc_row([
                dbc_col(gain_lose_table( results.gain_lose)),
                dbc_col(
                    dcc_graph(
                        figure=drawDeciles( 
                            results.summary.deciles[1][:,3],
                            BASE_STATE.summary.deciles[1][:,3])
                        )
                    )
            ]) # inner row for chart & table
        ]), # row1, col1
        dbc_col([
            html_h4(" Revenues and Costs"),
            costs_table(
                BASE_STATE.summary.income_summary[1],
                results.summary.income_summary[1])
        ]), # row1 col2
        dbc_col([      
                html_h4("Incentives - Marginal Effective Tax Rates.")
                mr_table( 
                    BASE_STATE.summary.metrs[1], 
                    results.summary.metrs[1] )
        ]) # row1 col3
    ]) # row 1

	row2 = dbc_row([		
        dbc_col([
            html_h4("Poverty"),
			pov_table(
				BASE_STATE.summary.poverty[1],
				results.summary.poverty[1])
        ]), # row2 col 1
        dbc_col( [
            html_h4("Inequality"),
            ineq_table(
                BASE_STATE.summary.inequality[1],
                results.summary.inequality[1])
        ]), # row2 col 2
        dbc_col( [
                dcc_graph(
                    figure=draw_lorenz(
                        BASE_STATE.summary.deciles[1][:,2],
                        results.summary.deciles[1][:,2]) 
                )
        ]) # row 2 col 3
    ]) # row 2
    return html_div([ row1, row2 ])    
end


function it_fieldset()
    it = html_fieldset([
        html_legend( "Income Tax"),
        dbc_row([
            dbc_col(
                dbc_label("Basic Rate (%)"; html_for="basic_rate")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "basic_rate",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 20.0,
                    step = 0.5 )
            ) # col
        ]),
        dbc_row([	
            dbc_col(
                dbc_label("Higher Rate (%)"; html_for="higher_rate")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "higher_rate",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 41.0,
                    step = 0.5 )
            ) # col
        ]), # row
        dbc_row([	
            dbc_col(
                dbc_label("Top Rate (%)"; html_for="top_rate")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "top_rate",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 46.0,
                    step = 0.5 )
            ) # col
        ]), # row
        dbc_row([	
            dbc_col(
                dbc_label("Personal Allowance £pa"; html_for="pa")
            ), # col
            dbc_col(
                dbc_input(
                    type="number",
                    id = "pa",
                    min = 0,
                    max = 50_000.0,
                    size = "4",
                    value = 12_570,
                    step = 1,
                    style=RESERVED )
            ) # col
        ]), # row
    ])
    return it
end

function ni_fieldset()
    ni = html_fieldset([
        html_legend( "National Insurance"),
        dbc_row([
            dbc_col(
                dbc_label("Employee's Rate(%)"; html_for="ni_prim")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "ni_prim",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 12.0,
                    step = 0.1,
                    style=RESERVED )
            ) # col
        ]),
        
        dbc_row([
            dbc_col(
                dbc_label("Employer's Rate(%)"; html_for="ni_sec")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "ni_sec",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 13.8,
                    step = 0.1,
                    style=RESERVED )
            ) # col
        ]), # row

    ])
    return ni
end

function ben_fieldset()
    bens = html_fieldset([
        html_legend( "Benefits"),
        dbc_row([
            dbc_col(
                dbc_label("Child Benefit £pw (1st child)"; html_for="cb")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "cb",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 21.15,
                    step = 0.05,
                    style=RESERVED )
            ) # col
        ]), # row
        dbc_row([
            dbc_col(
                dbc_label("New State Pension £pw"; html_for="pen")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "pen",
                    min = 0,
                    max = 500,
                    size = "4",
                    value = 179.60,
                    step = 0.10,
                    style=RESERVED )
            ) # col
        ]),
        dbc_row([
            dbc_col(
                dbc_label("Universal Credit Taper (%)"; html_for="uctaper")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "uctaper",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 55.0,
                    step = 0.5,
                    style=RESERVED )
            ) # col
        ]),       
        dbc_row([
            dbc_col(
                dbc_label("Universal Credit: single 25+ adult £pm"; html_for="ucs")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "ucs",
                    min = 0,
                    max = 1000,
                    size = "4",
                    value = 324.84,
                    step = 0.01,
                    style=RESERVED )
            ) # col
        ]), # row
        dbc_row([
            dbc_col(
                dbc_label("Working Tax Credit: basic amount £pa"; html_for="wtcb")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "wtcb",
                    min = 0,
                    max = 10_000,
                    size = "6",
                    value = 2_005,
                    step = 0.50,
                    style=RESERVED )
            ) # col
        ]), # row
        dbc_row([
            dbc_col(
                dbc_label("Scottish Child Payment; £pw"; html_for="scp")
            ),
            dbc_col(
                dbc_input(
                    type="number",
                    id = "scp",
                    min = 0,
                    max = 100,
                    size = "4",
                    value = 10.0,
                    step = 0.05 )
            ) # col
        ])
    ]) 
    return bens
end


function submit_button()
    dbc_button(
        id = "submit-button", 
        class_name="primary", 
        color = "primary",
        name = "Run",
        value = "Run", 
        children = "submit"
    )
end