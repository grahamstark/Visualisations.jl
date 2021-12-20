function thing_table(
    names::Vector{String}, 
    v1::Vector, 
    v2::Vector, 
    up_is_good::Vector{Int} )

    table = "<table class='table'>"
    table *= "<thead>
        <tr>
            <th></th><th>Before</th><th>After</th><th>Change</th>
        </tr>
        </thead>"

    diff = v2 - v1
    n = size(names)[1]
    rows = []
    for i in 1:n
        colour = "text-primary"
        if (up_is_good[i] !== 0) && (! (diff[i] ≈ 0))
            if diff[i] > 0
                colour = up_is_good[i] == 1 ? "text-success" : "text-danger"
             else
                colour = up_is_good[i] == 1 ? "text-danger" : "text-success"
            end # neg diff   
        end # non zero diff
        ds = diff[i] ≈ 0 ? "-" : fp(diff[i])
        row = "<tr><td>$(names[i])</td><td class='text-right'>$(f2(v1[i]))</td><td class='text-right'>$(f2(v2[i]))</td><td class='text-right $colour'>$ds</td></tr>"
        table *= row
    end
    table *= "</tbody></table>"
    return table
end

function frame_to_table(
    df :: DataFrame;
    up_is_good :: Vector{Int},
    prec :: Int = 2, 
    caption :: String = "",
    totals_col :: Int = -1 )
    table = "<table class='table table-borderless table-sm'>"
    table *= "<thead>
        <tr>
            <th></th><th class='text-right'>Before</th><th class='text-right'>After</th><th class='text-right'>Change</th>            
        </tr>
        </thead>"
    table *= "<caption>$caption</caption>"
    i = 0
    for r in eachrow( df )
        i += 1
        colour = "text-primary"
        if (up_is_good[i] !== 0) && (! (r.Change ≈ 0))
            if r.Change > 0
                colour = up_is_good[i] == 1 ? "text-success" : "text-danger"
             else
                colour = up_is_good[i] == 1 ? "text-danger" : "text-success"
            end # neg diff   
        end # non zero diff
        ds = r.Change ≈ 0 ? "-" : format(r.Change, commas=true, precision=prec )
        if ds != "-" && r.Change > 0
            ds = "+$(ds)"
        end 
        row_style = i == totals_col ? "class='text-bold table-info' " : ""
        b = format(r.Before, commas=true, precision=prec)
        a = format(r.After, commas=true, precision=prec)
        row = "<tr $row_style><th class='text-left'>$(r.Item)<td class='text-right'>$b</td><td class='text-right'>$a</td></tr>"
        table *= row
    end
    table *= "</tbody></table>"
    return table
end

function costs_table( incs1 :: DataFrame, incs2 :: DataFrame )
    df = costs_dataframe( incs1, incs2 )
    return frame_to_table( df, prec=0, up_is_good=COST_UP_GOOD, 
        caption="Tax Liabilities and Benefit Entitlements, £m pa, 2021/22" )
end


function overall_cost( incs1:: DataFrame, incs2:: DataFrame )
    n1 = incs1[1,:net_cost]
    n2 = incs2[1,:net_cost]
    
    eni1 = incs1[1,:employers_ni]
    eni2 = incs2[1,:employers_ni]
    d = (n1-eni1) - (n2-eni2)
    if d ≈ 0
        return
    end
    d /= 1_000_000
    colour = "alert-info"
    extra = ""
    change_str = "In total, your changes cost less than £1m"
    change_val = ""
    if abs(d) > 1
        change_val = f0(abs(d))
        if d > 0
            colour = "alert-success"
            change_str = "In total, your changes raise £"
            extra = "m."
        else
            colour = "alert-danger"
            change_str = "In total, your changes cost £"
            extra = "m."
        end
    end
    d = "<div class='alert $colour'>$change_str<strong>$change_val</strong>$extra</div>"
    return d
end

function mr_table( mr1, mr2 )
    df = mr_dataframe( mr1.hist, mr2.hist, mr1.mean, mr2.mean )
    n = size(df)[1]
    table = frame_to_table( 
        df, 
        prec=0, 
        up_is_good=MR_UP_GOOD, 
        caption="Working age individuals with Marginal Effective Tax Rates
                (METRs) in the given range. METR is the percentage of the next £1 you earn that is taken away in taxes or 
                reduced means-tested benefits.",
        totals_col = n )   
    return table
end


function ineq_table( ineq1 :: InequalityMeasures, ineq2 :: InequalityMeasures )
    df = ineq_dataframe( ineq1, ineq2 )
    up_is_good = fill( -1, 6 )
    return frame_to_table( 
        df, 
        prec=2, 
        up_is_good=up_is_good, 
        caption="Standard Inequality Measures, using Before Housing Costs Equivalised Net Income." )
end


function pov_table( 
    pov1 :: PovertyMeasures, 
    pov2 :: PovertyMeasures,
    ch1  :: GroupPoverty, 
    ch2  :: GroupPoverty )
    df = pov_dataframe( pov1, pov2, ch1, ch2 )
    up_is_good = fill( -1, 7 )
    return frame_to_table( 
        df, 
        prec=2, 
        up_is_good=up_is_good, 
        caption="Standard Poverty Measures, using Before Housing Costs Equivalised Net Income." )
end


function gain_lose_table( gl :: NamedTuple )
    lose = format(gl.losers, commas=true, precision=0)
    gain = format(gl.gainers, commas=true, precision=0)
    nc = format(gl.nc, commas=true, precision=0)
    losepct = md_format(100*gl.losers/gl.popn)
    gainpct = md_format(100*gl.gainers/gl.popn)
    ncpct = md_format(100*gl.nc/gl.popn)
    table = "<table class='table table-borderless table-sm'>"
    table *= "<thead>
        <tr>
            <th></th><th class='text-right'></th><th class='text-right'>%</th><th class='text-right'>Change</th>            
        </tr>
        </thead>
        <tbody>"
    caption = "Individuals living in households where net income has risen, fallen, or stayed the same respectively."
    table *= "<caption>$caption</caption>"
    table *= "<tr><th>Gainers</th><td class='text-right'>$gain</td><td class='text-right'>$(gainpct))</td></tr>"
    table *= "<tr><th>Losers</th><td class='text-right'>$lose</td><td class='text-right'>$(losepct))</td></tr>"
    table *= "<tr><th>Unchanged</th><td class='text-right'>$nc</td><td class='text-right'>$(ncpct))</td></tr>"
    table *= "</tbody></table>"
    return table
end

function results_to_html( uuid :: UUID, results :: AllOutput ) :: NamedTuple

    gain_lose = gain_lose_table( results.gain_lose )
    gains_by_decile = results.summary.deciles[1][:,3] -
			    BASE_STATE.summary.deciles[1][:,3]
    costs = costs_table( 
        BASE_STATE.summary.income_summary[1],
        results.summary.income_summary[1])
    mrs = mr_table(
        BASE_STATE.summary.metrs[1], 
        results.summary.metrs[1] )       
    poverty = pov_table(
        BASE_STATE.summary.poverty[1],
        results.summary.poverty[1],
        BASE_STATE.summary.child_poverty[1],
        results.summary.child_poverty[1])
    inequality = ineq_table(
        BASE_STATE.summary.inequality[1],
        results.summary.inequality[1])
    lorenz_pre = BASE_STATE.summary.deciles[1][:,2]
    lorenz_post = results.summary.deciles[1][:,2]
    out = ( 
        phase = "end", 
        uuid = uuid,
        gain_lose = gain_lose, 
        gains_by_decile = gains_by_decile,
        costs = costs, 
        mrs = mrs, 
        poverty=poverty, 
        inequality=inequality, 
        lorenz_pre=lorenz_pre, 
        lorenz_post=lorenz_post )
    return out
end