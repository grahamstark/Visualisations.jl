#
# As of September 19 2021
# Tests og budget constraints
#

using Test
using DataFrames
using PrettyTables

using ScottishTaxBenefitModel
using .ModelHousehold
using .STBParameters
using .STBIncomes
using .Definitions
using .GeneralTaxComponents
using .SingleHouseholdCalculations
using .RunSettings
using .Utils
using .ExampleHouseholdGetter
using .BCCalcs
using .ExampleHelpers


# COLS = [:gross,:mr,:label_pch]
COLS = [:gross,:net,:mr,:reduction,:label_pch]



function printbcs( 
    hh :: Household,
    sys :: TaxBenefitSystem, 
    wage::Real,
    settings::Settings )

    settings.means_tested_routing = lmt_full 
    bc = BCCalcs.makebc(
        hh, 
        sys, 
        settings, 
        wage )
    println("Legacy Case")
    pretty_table( bc[!,COLS] )

    settings.means_tested_routing = uc_full 
    bcu = BCCalcs.makebc(
        hh, 
        sys, 
        settings, 
        wage )
    println( "UC CASE ")
    pretty_table( bcu[!,COLS] )
end

sys21_22 = load_file( "../params/sys_2021_22.jl" )
load_file!( sys21_22, "../params/sys_2021-uplift-removed.jl")
println( "weeklyise start wpm=$PWPM wpy=52")
weeklyise!( sys21_22; wpy=52, wpm=PWPM  )

@testset "Single Pers bc" begin

    hh = crude_construct_hh( 
        "private", 
        2, 
        200.0, 
        "couple", 
        0, 
        0 )
    printbcs( hh, sys21_22, 20, DEFAULT_SETTINGS)
    println("6 bedrooms; 6 kids; 300 hcost")
    hh = crude_construct_hh( 
        "council", 
        6, 
        300.0, 
        "couple", 
        2, 
        4 )
    printbcs( hh, sys21_22, 20, DEFAULT_SETTINGS)




end
