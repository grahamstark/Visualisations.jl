window.stb = {}; // Create global container


// font-awsome free..
const UP_ARROW="fas fa-arrow-alt-circle-up";
const DOWN_ARROW="fas fa-arrow-alt-circle-down";
const NO_ARROW = "fas fa-minus-circle";

/*
 choice of arrows/numbers for the table - we use various uncode blocks;
 see: https://en.wikipedia.org/wiki/Arrow_(symbol)
 Of 'arrows', only 'arrows_3' displays correctly in Windows, I think,
 arrows_1 is prettiest
*/
const ARROWS_3 = { //  see https://en.wikipedia.org/wiki/Arrow_(symbol)
'nonsig'          : '&#x25CF;',
'positive_strong' : '&#x21c8;',
'positive_med'    : '&#x2191;',
'positive_weak'   : '&#x21e1;',
'negative_strong' : '&#x21ca;',
'negative_med'    : '&#x2193;',
'negative_weak'   : '&#x21e3;'}

const ARROWS_2 = { // see https://en.wikipedia.org/wiki/Arrow_(symbol)
'nonsig'          : '',
'positive_strong' : '&#x21e7;',
'positive_med'    : '&#x2191;',
'positive_weak'   : '&#x21e3;',
'negative_strong' : '&#x21e9;',
'negative_med'    : '&#x2193;',
'negative_weak'   : '&#x21e1;'}

const ARROWS_1 = { //  see https://en.wikipedia.org/wiki/Arrow_(symbol) Don't work on Windows Unicode 9
'nonsig'          : '',
'positive_strong' : '&#x1F881;',
'positive_med'    : '&#x1F871;',
'positive_weak'   : '&#x1F861;',
'negative_strong' : '&#x1F883;',
'negative_med'    : '&#x1F873;',
'negative_weak'   : '&#x1F863;' }

const CIRCLES = {
'nonsig'          : '&#x25CF;',
'positive_strong' : '&#x25CF;',
'positive_med'    : '&#x25CF;',
'positive_weak'   : '&#x25CF;',
'negative_strong' : '&#x25CF;',
'negative_med'    : '&#x25CF;',
'negative_weak'   : '&#x25CF;' }

const MARKS =
{ 'arrows_2' : ARROWS_2,
  'arrows_1' : ARROWS_1,
  'arrows_3' : ARROWS_3,
  'circles'  : CIRCLES }

stb.propToString = function( prop ){
    if( Math.abs( prop ) < 0.01 ){
        return 'nonsig';
    } else if ( prop > 0.1 ){
        return 'positive_strong';
    } else if ( prop > 0.05 ){
        return 'positive_med';
    } else if ( prop > 0.0 ){
        return 'positive_weak';
    } else if ( prop < -0.1 ){
        return 'negative_strong';
    } else if (prop < -0.05 ){
        return 'negative_med';
    } else if ( prop < 0 ){
        return 'negative_weak';
    }
    return "wtf!!";
}

stb.getArrowAndClass = function( change, prop ){
    if( Math.abs( prop) < 0.01 ){
        return {udclass:"no-change", arrow:NO_ARROW };
    } else if( prop > 0 ){
        return {udclass:"change-up", arrow:UP_ARROW };
    } else  {
        return {udclass:"change-down",arrow:DOWN_ARROW };
    }
}

stb.createNetCost = function( result ){
    var net_cost = result.totals[2].net_incomes/10**9;
    var view = {
        net_cost_str: "Under &#163;10m",
        udclass: "nonsig",
        dir: ""
    }
    if( Math.abs( net_cost ) >= 0.01 ){
        if( net_cost < 0 ){
            net_cost *= -1;
            view.dir = "Less";
            view.udclass = "positive_strong";
        } else {
            view.dir = "More";
            view.udclass = "negative_strong";
        }
        view.net_cost_str = "&#163;"+numeral(net_cost).format( '0,0')+"&nbsp;bn";
    }
    view.arrow = ARROWS_2[view.udclass];
    var output = Mustache.render( "<p class='{{udclass}}'> {{{net_cost_str}}} {{dir}}</strong> {{{arrow}}}</p>", view );
    $( "#net-cost" ).html( output );
}

stb.createMarginalRates = function( result ){

    var over75 = 0.0;
    var over75_change = 0.0;
    var tot = 0.0;
    for( var i = 0; i < result.metr_histogram[1].length; i++ ){
        tot += result.metr_histogram[1][i];
        // FIXME brittle
        if( i >= 4){
            over75 += result.metr_histogram[1][i];
            over75_change += result.metr_histogram[2][i];
        }
    }
    over75 /= tot;
    over75_change /= tot;

    metr = result.avg_metr[2];
    var view = {
        av_marg_str: numeral(100.0*result.avg_metr[1]).format( '0,0')+"%",
        av_marg_change_str: numeral(100.0*metr).format( '0,0'),
        udclass: stb.propToString( -metr ),
        over75: numeral(100.0*over75).format( '0,0')+"%",
        over75_change: numeral(100.0*over75_change).format( '0,0'),
        arrow: ARROWS_2[ stb.propToString( metr)]
    }

    var output = Mustache.render(
        "<ul class='{{udclass}}'>"+
            "<li>Average: {{{av_marg_str}}} ({{{arrow}}} {{{av_marg_change_str}}}) </li>"+
            "<li>Above 75%: {{{over75}}} ({{{over75_change}}})</li>"+
        "</ul>", view );
    $( "#marginal-rates" ).html( output );
}

stb.createOneMainOutput = function( element_id, name, totals, pos, down_is_good ){
    console.log( "typeof totals " + typeof( totals ));
    console.log( "totals length" + totals.length );
    console.log( "totals " + totals.toString() );

    var nc = totals[2][pos];
    var pc = nc/totals[0][pos];
    var arrow_str = stb.propToString( pc );
    var udclass = arrow_str;
    if( down_is_good ){
        udclass= stb.propToString( -pc ); // point the arrow in the opposite direction
    }
    var view = {
        udclass: udclass,
        arrow: ARROWS_2[arrow_str]
    }
    view.which_thing = name;
    view.net_cost_str = "&#163;"+numeral(nc/(10**9)).format( '0,0')+"&nbsp;bn";
    view.pc_cost_str = numeral(pc*100).format( '0,0.0')+"%";

    var output = "<p>No Change</p>";
    if( udclass !== 'nonsig'){
        output = Mustache.render( "<p class='{{{udclass}}}'>{{{net_cost_str}}} ({{{arrow}}} {{{pc_cost_str}}}) </p>", view );
    }
    $( "#"+element_id ).html( output );
}

stb.createGainLose = function( result ){
    var view = {}
    view.gainers = numeral(result.gainlose_totals.gainers).format('0,0');
    view.nc = numeral(result.gainlose_totals.nc).format('0,0');
    view.losers = numeral(result.gainlose_totals.losers).format('0,0');
    view.gainers_pct = numeral(100.0*result.gainlose_totals.gainers/result.unit_count).format('0,0.0');
    view.nc_pct = numeral(100.0*result.gainlose_totals.nc/result.unit_count).format('0,0.0');
    view.losers_pct = numeral(100.0*result.gainlose_totals.losers/result.unit_count).format('0,0.0');
    var output = Mustache.render(
        "<ul>"+
        "<li class='negative_med''>Losers: {{losers}} ({{losers_pct}}%)</li>"+
        "<li class=''>Unchanged: {{nc}} ({{nc_pct}}%)</li> "+
        "<li class='positive_med'>Gainers: {{gainers}} ({{gainers_pct}}%)</li>"+
        "</ul>", view );
    $( "#gainers-and-losers" ).html( output );

}

stb.createInequality = function( result ){
    var gini_change = result.inequality[2]['gini']
    var udclass = stb.propToString( -gini_change );
    var gini_post = numeral( result.inequality[1]['gini']*100 ).format( '0,0.0');
    var gini_change = numeral( result.inequality[2]['gini']*100 ).format( '0,0.0');
    var view = {
        gini_post: gini_post,
        gini_change:gini_change,
        udclass: udclass,
        arrow: ARROWS_2[stb.propToString(gini_change)]
    };
    if( udclass == 'nonsig'){
        view.gini_change = 'unchanged';
    }
    var output = Mustache.render( "<p class='{{udclass}}'> {{{gini_post}}} ({{{arrow}}} {{{gini_change}}}) </p>", view );
    $( "#inequality" ).html( output );
    stb.createLorenzCurve( "#lorenz", result, true );
}

stb.createPoverty = function( result ){
    var hcv = result.poverty[2].headcount;
    var udclass = stb.propToString( -hcv );
    var headcount_post = numeral( 100.*result.poverty[1].headcount ).format( '0,0.0')+"%";
    var headcount_change = numeral( 100.*result.poverty[2].headcount ).format( '0,0.0')+"%";
    var gap_post = numeral( 100.0*result.poverty[1].gap ).format( '0,0.0');
    var gap_change = numeral( 100.0*result.poverty[2].gap ).format( '0,0.0');
    var fgt_post = numeral( 100.0*result.poverty[1].foster_greer_thorndyke[4]).format( '0,0.0');
    var fgt_change = numeral( 100.0*result.poverty[2].foster_greer_thorndyke[4] ).format( '0,0.0');

    var view = {
        headcount_post: headcount_post,
        headcount_change:headcount_change,
        gap_post: gap_post,
        gap_change:gap_change,
        fgt_post: fgt_post,
        fgt_change:fgt_change,

        udclass: udclass,
        arrow: ARROWS_2[ stb.propToString(hcv) ]
    };
    if( udclass == 'nonsig'){
        view.headcount_change = '-';
    }
    var output = Mustache.render( "<ul class='{{udclass}}'>"+
      "<li>Headcount: {{{headcount_post}}} ({{{arrow}}} {{{headcount_change}}}) </li>"+
      "<li>Poverty Gap: {{{gap_post}}} ({{{arrow}}} {{{gap_change}}}) </li>"+
      "<li>Severity (FGT): {{{fgt_post}}} ({{{arrow}}} {{{fgt_change}}}) </li>"+
      "</ul>", view );
    $( "#poverty" ).html( output );
}

stb.createTargetting = function( result ){
    var output = "<p>NA</p>";
    var targetted = "";
    var cutOrInc = "";
    console.log( "result.targetting_total_benefits[2]="+result.targetting_total_benefits[2]);
    if( Math.abs( result.totals[2].total_benefits ) > 0.01 ){ // any change in total benefits
        targetted = numeral(result.targetting_total_benefits[2]).format('0,0.0' )+"%"; // already in %
        if(result.totals[2].total_benefits[2] > 0.0 ){ // net increase in spending
            cutOrInc = "increases";
        } else {  // net cuts
            cutOrInc = "cuts";
        }
        var view = {
            targetted: targetted,
            cut_or_inc: cutOrInc
        };
        output = Mustache.render( "<p>proportion of benefit {{cut_or_inc}} targetted on poor: {{targetted}}.</p>", view );
    }
    $( "#targetting" ).html( output );
}


const GOLDEN_RATIO = 1.618

stb.createLorenzCurve = function( targetId, result, thumbnail ){
    var height = 300;
    var xtitle = "Population Share";
    var ytitle = "Income Share";
    var title = "Lorenz Curve"
    if( thumbnail ){
        var height = 70;
        xtitle = "";
        ytitle = "";
        title = "";
    }
    var width = Math.trunc( GOLDEN_RATIO*height);
    var data=[];
    console.log( "deciles" + result.lorenz_pre.toString());
    console.log( "lorenz_pre length" + result.lorenz_pre.length );
    // deciles levels are rhs. so push a 0,0
    data.push( {"popn1":0, "pre":0 });
    popn = 0.0;
    incr = 1/result.lorenz_pre.length;
    for( var i = 0; i < result.lorenz_pre.length; i++){
        popn += incr;
        data.push( {"popn1":popn, "pre":result.lorenz_pre[i] });
    }
    // var data_post= [];
    data.push( {"popn2":0, "post":0 });
    popn = 0.0;
    for( var i = 0; i < result.lorenz_post.length; i++){
        popn += incr;
        data.push( {"popn2":popn, "post":result.lorenz_post[i] });
    }
    data.push( {"popn3":0.0, "base":0.0});
    data.push( {"popn3":1.0, "base":1.0});
    var gini_vg = {
        "$schema": "https://vega.github.io/schema/vega-lite/v3.json",
        "title": title,
        "width": width,
        "height": height,
        "description": title,
        "data": {"values": data }, // , "post":data_post
        "layer":[
            {
                "mark": "line",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "popn1",
                           "axis":{
                               "title": xtitle
                           }},
                    "y": { "type": "quantitative",
                           "field": "pre",
                           "axis":{
                              "title": ytitle
                           } },
                    "color": {"value":"blue"}
                } // encoding
            }, // pre layer line
            {
                "mark": "line",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "popn2",
                           "axis":{
                              "title": xtitle
                           }},
                    "y": { "type": "quantitative",
                           "field": "post",
                           "axis":{
                              "title": ytitle
                           } },
                   "color": {"value":"red"}
               } // encoding
           }, // post line
          { // diagonal in grey
               "mark": "line",
               "encoding":{
                   "x": { "type": "quantitative",
                          "field": "popn3" },
                   "y": { "type": "quantitative",
                          "field": "base" },
                   "color": {"value":"#ccc"},
                   "strokeWidth": {"value": 1.0}
                   // "strokeDash":
               } // encoding
           },
        ]
    }
    vegaEmbed( targetId, gini_vg );
}

stb.createDecileBarChart = function( targetId, result, thumbnail ){
    var height = 300;
    var xtitle = "Deciles";
    var ytitle = "Gains in £s p.w.";
    var title = "Gains By Decile"
    if( thumbnail ){
        var height = 70;
        xtitle = "";
        ytitle = "";
        title = "";
    }
    var width = Math.trunc( GOLDEN_RATIO*height);
    var data=[];
    console.log( "deciles" + result.gains_by_decile.toString());
    console.log( "lorenz_pre[2] length" + result.gains_by_decile.length );
    for( var i = 0; i < result.gains_by_decile.length; i++){
        var dec = (i+1);
        data.push( {"decile":dec, "gain":result.gains_by_decile[i] });
    }
    var deciles_vg = {
        "$schema": "https://vega.github.io/schema/vega-lite/v3.json",
        "title": title,
        "width": width,
        "height": height,
        "description": title,
        "data": {"values": data }, // , "post":data_post
        "mark": "bar",
        "encoding":{
            "x": { "type": "ordinal",
                   "field": "decile",
                   "axis":{
                      "title": xtitle
                   }
             },
            "y": { "type": "quantitative",
                   "field": "gain",
                   "axis":{
                      "title": ytitle
                   }
            }
        } // encoding
    }
    console.log( "deciles_vg=" + JSON.stringify(deciles_vg) );

    vegaEmbed( targetId, deciles_vg );
}

stb.createGainsByDecile = function( result ){
    stb.createDecileBarChart( '#deciles', result, true );
}


stb.createMainOutputs = function( result ){
    stb.createNetCost( result );
    stb.createOneMainOutput( "taxes-on-income", "Taxes on Incomes", result.totals, "total_taxes", false );
    stb.createOneMainOutput( "benefits-spending", "Spending on Benefits", result.totals, "total_benefits", true );
    stb.createOneMainOutput( "taxes-on-spending", "Taxes on Spending", result.totals, "total_indirect", false );
    stb.createInequality( result );
    stb.createGainsByDecile( result );
    stb.createGainLose( result );
    stb.createPoverty( result );
    stb.createTargetting( result );
    stb.createMarginalRates( result );
}

stb.annotationToString = function( annotation ){
    var mrs = "na";
    var tc = "na";
    if( annotation.taxcredit < 999 ){
        mrs = numeral( annotation.marginalrate*100 ).format( '0,0.0');
        tc = numeral( annotation.taxcredit ).format( '0,0.0');
    }
    return "Marginal Rate: "+mrs+"% Tax Credit: £"+tc;
}



stb.createBCOutputs = function( result ){
    var pre = result.base;
    var changed = result.changed;
    var data = [];
    var n = pre.points[1].length;
    for( var i = 0; i < n; i++){
        var annotation = "";
        if( i < (n-1)){
            annotation = stb.annotationToString(pre.annotations[i]);
        }
        data.push( {"gross1":pre.points[0][i], "pre":pre.points[1][i], "ann_pre":annotation })
    }
    // var data_post= [];
    n = changed.points[1].length;
    for( var i = 0; i < n; i++){
        var annotation = "";
        if( i < (n-1)){
            annotation = stb.annotationToString(changed.annotations[i]);
        }
        data.push( {"gross2":changed.points[0][i], "post":changed.points[1][i], "ann_post":annotation })
    }

    data.push( {"gross3":0.0, "base":0.0});
    data.push( {"gross3":2000.0, "base":2000.0});
    console.log( data );

    var budget_vg = {
        "$schema": "https://vega.github.io/schema/vega-lite/v3.json",
        "title": "Budget Constraint",
        "width": 600,
        "height": 600,
        "description": "Budget Constraint",
        "data": {"values": data }, // , "post":data_post
        "layer":[
            {
                "mark": "point",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "gross1",
                           "axis":{
                               "title": "Gross Income (£pw)"
                           }},
                    "y": { "type": "quantitative",
                           "field": "pre",
                           "axis":{
                              "title": "Net Income (£pw)"
                           } },
                    "color": {"value":"blue"}
                } // encoding
            }, // pre layer point
            {
                "mark": "point",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "gross2",
                           "axis":{
                              "title": "Gross Income (£pw)"
                           }},
                    "y": { "type": "quantitative",
                           "field": "post",
                           "axis":{
                              "title": "Net Income (£pw)"
                           } },
                   "color": {"value":"red"}
               } // encoding
           }, // post later point
           {
                "mark": "line",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "gross1" },
                    "y": { "type": "quantitative",
                           "field": "pre" },
                    "color": {"value":"blue"},
                    "tooltip": {"field":"ann_pre", "type":"nominal"  }
                } // encoding
            }, // pre layer line
           {
               "mark": "line",
               "encoding":{
                   "x": { "type": "quantitative",
                          "field": "gross2" },
                   "y": { "type": "quantitative",
                          "field": "post" },
                  "color": {"value":"red"},
                  "tooltip": { "field":"ann_post", "type":"nominal" }
              } // encoding
          },
          { // diagonal in grey
               "mark": "line",
               "encoding":{
                   "x": { "type": "quantitative",
                          "field": "gross3" },
                   "y": { "type": "quantitative",
                          "field": "base" },
                   "color": {"value":"#ccc"},
                   "strokeWidth": {"value": 1.0}
                   // "strokeDash":
               } // encoding
           }, // pre layer line

 // post layer line
        ]
    }
    vegaEmbed('#output', budget_vg );
}

// singles series version of above - FIXME really refactor these ..
stb.createOneLorenz = function( targetId, lorenz_pre, lorenz_post, thumbnail ){
    var height = 400;
    var xtitle = "Population Share";
    var ytitle = "Income Share";
    var title = "Lorenz Curve"
    if( thumbnail ){
        var height = 70;
        xtitle = "";
        ytitle = "";
        title = "";
    }
    var width = Math.trunc( GOLDEN_RATIO*height);
    var data=[];
    console.log( "deciles="+JSON.stringify(lorenz_pre));
    console.log( "lorenz_pre length" + lorenz_pre.length );
    // deciles levels are rhs. so push a 0,0
    data.push( {"popn":0, "income":0 });
    for( var i = 0; i < lorenz_pre.length; i++){
        data.push( {"popn":lorenz_pre[i], "income":lorenz_post[i] });
    }
    // diagonal in grey
    data.push( {"popn_tot":0.0, "income_tot":0.0});
    data.push( {"popn_tot":1.0, "income_tot":1.0});
    var gini_vg = {
        "$schema": "https://vega.github.io/schema/vega-lite/v3.json",
        "title": title,
        "width": width,
        "height": height,
        "description": title,
        "data": {"values": data }, // , "post":data_post
        "layer":[
            {
                "mark": "line",
                "encoding":{
                    "x": { "type": "quantitative",
                           "field": "popn",
                           "axis":{
                               "title": xtitle
                           }},
                    "y": { "type": "quantitative",
                           "field": "income",
                           "axis":{
                              "title": ytitle
                           } },
                    "color": {"value":"blue"}
                } // encoding
            }, // pre layer line
          { // diagonal in grey
               "mark": "line",
               "encoding":{
                   "x": { "type": "quantitative",
                          "field": "popn_tot" },
                   "y": { "type": "quantitative",
                          "field": "income_tot" },
                   "color": {"value":"#ccc"},
                   "strokeWidth": {"value": 1.0}
                   // "strokeDash":
               } // encoding
           },
        ]
    }
    vegaEmbed( targetId, gini_vg );
}

stb.loadInequalityTable = function( result ){
    console.log( "createInequalityTable");
    console.log( "result="+JSON.stringify(result));
    var pops = 0;
    var incs = 0;
    var cuminc=[];
    var cumpop=[]
    for( var i = 0; i < NUM_INC_BANDS; i++ ){
        pops += result.data[0][i];
        incs += result.data[1][i];
        cumpop.push(pops);
        cuminc.push(incs);
    }
    var sharepop=[];
    var shareinc=[];
    for( var i = 0; i < NUM_INC_BANDS; i++ ){
        var shp = numeral(100.0*cumpop[i]/cumpop[9]).format( '0,0')
        var shi = numeral(100.0*cuminc[i]/cuminc[9]).format( '0,0.00')
        sharepop.push( shp );
        shareinc.push( shi );
    }
    console.log( "sharepop="+JSON.stringify(sharepop));
    console.log( "shareinc="+JSON.stringify(shareinc));

    for( var i = 1; i <= NUM_INC_BANDS; i++ ){
        $( "#pop-"+i ).val( result.data[0][i-1] )
        $( "#inc-"+i ).val( result.data[1][i-1] )
        $( "#cum-pop-"+i ).html( cumpop[i-1] );
        $( "#cum-inc-"+i ).html( cuminc[i-1] );
        $( "#share-pop-"+i ).html( sharepop[i-1] );
        $( "#share-inc-"+i ).html( shareinc[i-1] );
    }
    $( "#mean" ).html( numeral(result.ineq.average_income).format('0,0.0'));
    $( "#median" ).html( numeral(result.ineq.median).format('0,0.0') );
    $( "#gini" ).html( numeral(result.ineq.gini).format('0,0.000') );
    $( "#theil" ).html( numeral(result.ineq.theil[0]).format('0,0.000') ); // CHECK!!
    $( "#palma" ).html( numeral(result.ineq.palma).format('0,0.00') );
    stb.createOneLorenz( "#lorenz", result.ineq.deciles, false );
}

const NUM_INC_BANDS = 10;

stb.sortByInc = function( a, b ){
    return a["inc"]-b["inc"];
}

stb.runInequality = function( ){
    console.log( "runInequality called");
    var data=[];
    for( var i = 1; i <= NUM_INC_BANDS; i++ ){
        var pop = parseFloat($("#pop-"+i).val());
        var inc = parseFloat($("#inc-"+i).val());
        var item = {pop:pop, inc:inc}
        data.push( item );
    }
    data.sort( stb.sortByInc );
    var inca=[];
    var popa=[];
    for( var i = 0; i < NUM_INC_BANDS; i++ ){
        popa.push(data[i]["pop"]);
        inca.push(data[i]["inc"]);
    }
    console.log( "incomes="+JSON.stringify(inca));
    $.ajax(
        { url: "/oustb/ineq/",
         method: 'get',
         dataType: 'json',
         data: { // can't get Julia to parse an json array correctly, so..
             pop_1:popa[0],
             pop_2:popa[1],
             pop_3:popa[2],
             pop_4:popa[3],
             pop_5:popa[4],
             pop_6:popa[5],
             pop_7:popa[6],
             pop_8:popa[7],
             pop_9:popa[8],
             pop_10:popa[9],
             inc_1:inca[0],
             inc_2:inca[1],
             inc_3:inca[2],
             inc_4:inca[3],
             inc_5:inca[4],
             inc_6:inca[5],
             inc_7:inca[6],
             inc_8:inca[7],
             inc_9:inca[8],
             inc_10:inca[9]
         },
         success: function( result ){
             console.log( "stb; call OK");
             console.log( "result " + result );
             stb.loadInequalityTable( result, data );
         }
     });
}


var updater;
var uuid;

stb.drawProgressBar = function( result ){
    // https://getbootstrap.com/docs/5.0/components/progress/
    console.log( "result.count" + result.count + "result.total" + result.total );
    var pct = Math.trunc(100 * result.count / result.total);
    var prog = 
        "<p>Model Running</p>"+
        "<div class='progress'>"+
        "<div class='progress-bar bg-success progress-bar-animated progress-bar-striped' role='progressbar' "+
            "aria-valuenow='" + pct + "' " + 
            "style='width: "+pct+"%' " +
            "aria-valuemin='0' " +
            "aria-valuemax='100'>"+
            pct + "%" +
            "</div> "+
            "</div>";
    console.log( "prog="+prog )
    $("#progress-indicator").html( prog );
}

stb.createMainOutputs = function( result ){
    console.log( result.inequality );
    console.log( result.examples );
    console.log( result.overall_costs )
    $("#examples").html( result.examples );
    $("#gain-lose-table").html( result.gain_lose );
    stb.createDecileBarChart( 
        "#deciles-graph", 
        result, 
        false );
    $("#costs-table").html( result.costs );
    $("#overall-costs").html( result.overall_costs )
    $("#mr-table").html( result.mrs );
    $("#pov-table").html( result.poverty );
    $("#ineq-table").html( result.inequality );
    stb.createLorenzCurve( 
        "#lorenz", 
        result,
        false );
}

stb.updateSTB = function( result, success, xhr, handle ){
    console.log( "updateSTB success=" + success + "| result.phase = " + result.phase );
    switch( result.phase ){
        case 'missing':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Run "+result.uuid+" is waiting to start found.</div>");
            break;
        case 'start':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Run starting: starting pre-run routines.</div>");
            break;
        case 'weights':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Generating sample weights (may take some time..).</div>");
            break;
        case 'disability_eligibility':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Calibrating Disability Benefits.</div>");
            break;
        case 'starting':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Pre-routines completed; run starting.</div>");
            break;
        case 'run':
            stb.drawProgressBar( result );
            break;
        case 'dumping_frames':
            $("#progress-indicator").html( "<div class='alert alert-info' role='alert'>Calculations complete; now generating output.</div>");
            break;
        case 'end':
            $("#progress-indicator").html( "<div></div>" );
            stb.createMainOutputs( result );
            updater.stop();
            break;  
        default:
            $("#progress-indicator").html( "<div class='alert alert-danger' role='alert'>Problem: run "+result.uuid+" can't be found.</div>");
            break;                                      
    }
}

// see: https://stackoverflow.com/questions/11338774/serialize-form-data-to-json
// note this doesn't work with checkbox groups
stb.getFormData = function(){
    var unindexed_array = $("#mainform").serializeArray();
    var indexed_array = {};
    console.log( "unindexed_array" + unindexed_array);
    $.map(unindexed_array, function(n, i){
        indexed_array[n['name']] = n['value'];
    });
    console.log( "indexed_array=" + indexed_array);
    return indexed_array;
}

stb.runModel = function(){
    console.log( "run model called");
    var it_basic_rate = $("#it-basic-rate").val();
    var it_higher_rate = $("#it-higher-rate").val();
    var it_top_rate = $("#it-top-rate").val();
    var it_pa = $("#it-pa").val();
    var bi_adult = $("#bi-adult").val();
    var bi_pensioner = $("#bi-pensioner").val();
    var bi_pens_age = $("#bi-pens-age").val();
    var bi_child = $("#bi-child").val();
    var bi_adult_age = $("#bi-adult-age").val();
    var ubi_mtbens_keep_as_is = $("#ubi-mtbens-keep-as-is").prop('checked');
    var ubi_mtbens_abolish = $("#ubi-mtbens-abolish").prop('checked');
    var ubi_mtbens_keep_housing = $("#ubi-mtbens-keep-housing").prop('checked');
    var ubi_abolish_sick = $("#ubi-abolish-sick").prop('checked');
    var ubi_abolish_pensions = $("#ubi-abolish-pensions").prop('checked');
    var ubi_abolish_esa = $("#ubi-abolish-esa").prop('checked');
    var ubi_abolish_others = $("#ubi-abolish-others").prop('checked');
    var ubi_as_mt_income = $("#ubi-as-mt-income").prop('checked');
    var ubi_taxable = $("#ubi-taxable").prop('checked');
    $.ajax(
        // make the UBI bit a variable
        { url: "/bi/run/",
         method: 'get',
         dataType: 'json',
         data: {
            it_basic_rate: it_basic_rate,
            it_higher_rate: it_higher_rate,
            it_top_rate: it_top_rate,
            it_pa: it_pa,
            bi_adult: bi_adult,
            bi_pensioner: bi_pensioner,
            bi_pens_age: bi_pens_age,
            bi_child: bi_child,
            bi_adult_age: bi_adult_age,
            ubi_mtbens_keep_as_is: ubi_mtbens_keep_as_is,
            ubi_mtbens_abolish: ubi_mtbens_abolish,
            ubi_mtbens_keep_housing: ubi_mtbens_keep_housing,
            ubi_abolish_sick: ubi_abolish_sick,
            ubi_abolish_pensions: ubi_abolish_pensions,
            ubi_abolish_esa: ubi_abolish_esa,
            ubi_abolish_others: ubi_abolish_others,
            ubi_as_mt_income: ubi_as_mt_income,
            ubi_taxable: ubi_taxable  }      
        }).done( 
             function( result ){
                if( result. ){

                } else {                
                    uuid = result;
                    console.log( "stb; call OK "+uuid );
                    console.log( "result " + result );
                    var uri = '/bi/progress/'+uuid;
                    updater = $.PeriodicalUpdater( uri, {}, stb.updateSTB );
                }
        }).fail(function( jqXHR, textStatus, errorThrown ){
            console.log( "failed with " + textStatus + " errorThrown "+errorThrown );
            console.log( "jqXHR.statusCode" + jqXHR.status + " text" + jqXHR.statusText );

        });
        /*
        }, 
         error: function( xq, textStatus, errorThrown ){
            console.log( "ERROR" + errorThrown + "; xq "+xq + "textStatus " + textStatus );
         }
         */
     // });
}