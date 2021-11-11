using Test
using ScottishTaxBenefitModel.Uprating
using DataFrames
using ScottishTaxBenefitModel
using .RunSettings: Settings, DEFAULT_SETTINGS
using .ModelHousehold
using .ExampleHouseholdGetter
using .FRSHouseholdGetter
using .Definitions
using .ExampleHelpers

prfr = Uprating.load_prices( DEFAULT_SETTINGS )

print( prfr )

@time thesenames = ExampleHouseholdGetter.initialise( DEFAULT_SETTINGS )

## NOTE this test has the 2019 OBR data and 2019Q4 as a target jammed on - will need
## changing with update versions

@testset "uprating tests" begin
    hh = ExampleHouseholdGetter.get_household( "mel_c2_scot" )
    hh.quarter = 1
    hh.interview_year = 2008
    pers = hh.people[SCOT_HEAD]
    # average index 2008 q1=100; 2019 Q4 = 125.9812039916
    pers.income[wages] = 100.0
    uprate!( hh )
    # FIXME hardly a test & needs changed every time the index changes
    @test pers.income[wages] ≈ 100*19.66933/15.1875 # 2021q2 av wages index
end
