
const MR_UP_GOOD = [1,0,0,0,0,0,0,-1,-1]
const COST_UP_GOOD = [1,1,1,1,-1,-1,-1,-1,-1,-1,-1]

function format_and_class( change :: Real ) :: Tuple
    gnum = format( abs(change), commas=true, precision=2 )
    glclass = "";
    glstr = ""
    if change > 20.0
        glstr = "positive_strong"
        glclass = "text-success"
    elseif change > 10.0
        glstr = "positive_med"
        glclass = "text-success"
    elseif change > 0.01
        glstr = "positive_weak"
        glclass = "text-success"
    elseif change < -20.0
        glstr = "negative_strong"
        glclass = "text-danger"
    elseif change < -10
        glstr = "negative_med"
        glclass = "text-danger"
    elseif change < -0.01
        glstr = "negative_weak"
        glclass = "text-danger"
    else
        glstr = "nonsig"
        glclass = "text-body"
        gnum = "";
    end
    ( gnum, glclass, glstr )
end