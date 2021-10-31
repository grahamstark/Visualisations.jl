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
        width=700, 
        height=700)

    pre = scatter(
        x=xr, 
        y=v1, 
        mode="line", 
        name="Post" )

    post = scatter(
        x=xr, 
        y=v2, 
        mode="line", 
        name="Post" )

    diag = scatter(y=[0,1], x=[0,1], showlegend=false, name="")
    
    return PlotlyJS.plot( [pre, post, diag], layout)
end

function drawDeciles( pre::Vector, post :: Vector )
    v = pre-post;
    return Plotly.plot( 
        1:10, 
        v, 
        type=:bar )
	
end