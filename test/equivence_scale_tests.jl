using Test
using ScottishTaxBenefitModel
using .EquivalenceScales:  
    EQScales, 
    EQ_Person, 
    get_equivalence_scales,
    EQ_P_Type,
    eq_spouse_of_head,
    eq_other_adult,
    eq_head


@testset "Eq Scales" begin
    for (key,hh) in EXAMPLES
        eqs :: EQScales = get_equivalence_scales( 
            Float64,
            collect(values(hh.people)))
        println( "hh $key $eqs" )
    end
end