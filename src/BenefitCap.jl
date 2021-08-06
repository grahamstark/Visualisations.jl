module BenefitCap
#
# Apply the benefit cap as described in CPAG 19/20
# ch 52. Somewhat impressionistic and could do 
# with another go.
# 
using ScottishTaxBenefitModel

using .ModelHousehold: 
    BenefitUnit,
    Household, 
    Person

using .STBParameters: 
    BenefitCapSys

using .Definitions

using .Intermediate:
    MTIntermediate

export apply_benefit_cap!

"""
Apply a benefit cap to a benefit unit.
"""
function apply_benefit_cap!( 
    benefit_unit_result :: BenefitUnitResult,
    region           :: Standard_Region
    benefit_unit     :: BenefitUnit,
    intermed         :: MTIntermediate,
    caps             :: BenefitCapSys
    route            :: LegacyOrUC )
    # FIXME CPAG 19/20 p 1190 does this on some benefit
    # receipts but this is likely near enough.
    if intermed.someone_pension_age || 
        intermed.someone_is_carer ||
        (intermed.num_severely_disabled_adults > 0)
        return
    end
    bu = benefit_unit # shortcut
    bur = benefit_unit_result # shortcut
    cap = intermed.num_people == 1 ? 
        caps.outside_london_single :
        outside_london_couple
    if region == London
        cap = intermed.num_people == 1 ? 
            caps.inside_london_single :
            inside_london_couple
    end
    totbens = 0.0
    included = UC_CAP_BENEFITS
    target_ben = UNIVERSAL_CREDIT
    min_amount = bur.uc.childcare_costs
    if route == legacy_bens 
        included = LEGACY_CAP_BENEFITS 
        target_ben = HOUSING_BENEFIT
        min_amounr = 0.5
    end        
    recip_pers :: BigInt = -1
    recip_ben = 0.0
    for (pid) in bu.adults
        totbens += isum( bur.pers[pid].income, included )
        if bur.pers[pid].income[target_ben] > 0
            recip_pers = pid
            recip_ben = bur.pers[pid].income[target_ben]
        end
    end
    if recip_ben == 0.0
        return
    end
    excess = totbens - cap
    if excess > min_amount
        rd = max( min_amount, recip_ben - excess )
        bur.bencap.reduction = recip_ben - rd        
        bur.pers[recip_pers].income[target_ben] = rd
    end
    bur.bencap.cap_benefits = totbens
    bur.bencap.cap = cap
end # cap_benefits

end # module