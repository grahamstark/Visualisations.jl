module LegacyMeansTestedBenefits

using Parameters: @with_kw

using ScottishTaxBenefitModel
using .Definitions
using .ModelHousehold: Person,BenefitUnit,Household, is_lone_parent,
    is_disabled, is_carer
using .STBParameters: LegacyMeansTestedBenefitSystem, IncomeRules, 
    Premia, PersonalAllowances
using .GeneralTaxComponents: TaxResult, calctaxdue, RateBands
using .Results: BenefitUnitResult, HouseholdResult, IndividualResult
using .Utils: mult

export calc_legacy_means_tested_benefits, LMTResults

@with_kw mutable struct LMTResults{RT<:Real}
    esa :: RT = zero(RT)
    hb  :: RT = zero(RT)
    is :: RT = zero(RT)
    jsa :: RT = zero(RT)
    pc  :: RT = zero(RT)
    ndds :: RT = zero(RT)
    wtc  :: RT = zero(RT)
    ctc  :: RT = zero(RT)
    intermediate :: Dict = Dict()
end

struct LMTIncomes{RT<:Real}
    gross_earnings :: RT
    net_earnings   :: RT
    total_income   :: RT
end

function calc_incomes( 
    which_ben :: LMTBenefitType, # esa hb is jsa pc wtc ctc
    bu :: BenefitUnit, 
    bur :: BenefitUnitResult, 
    sys :: IncomeRules ) :: LMTIncomes 
    T = typeof( sys.permitted_work )
    extra_incomes = zero(T)
    gross_earn = zero(T)
    net_earn = zero(T)
    other = zero(T)
    total = zero(T)
    is_sparent = is_lone_parent( bu )
    is_single = is_single_person( bu )
    is_disabled = has_disabled_member( bu )
    is_carer = has_carer_member( bu )
    if which_ben == hb
        inclist = sys.hb_incomes
    else
        inclist = sys.incomes
    end
    # children's income doesn't count see cpag p421, so:
    for pid in bu.adults
        pers = bu.people[pid]
        pres = bur.pers[pid]
        gross = 
            get( pers.income, wage, 0.0 ) +
            get( pers.income, self_employment_income, 0.0 ) # this includes losses
        net = 
            gross - ## FIXME parameterise this so we can use gross/net
            pres.it.non_savings -
            pres.ni.total_ni - 
            0.5 * get(pers.income, pension_contributions_employee, 0.0 )
        gross_earn += gross
        net_earn += max( 0.0, net )
        other += sum( 
            data=pers.income, 
            calculated=pres.incomes, 
            included=inclist )
    end
    # disregards
    # if which_ben in [hb,jsa,is,]
    # FIXME this is not quite right for ESA
    disreg = 0.0
    if is_sparent
        disreg = which_ben == hb ? sys.lone_parent_hb : sys.high # 25 or 20
    elseif is_disabled || is_carer 
        disreg = sys.high
    else
        
    end
    
    # end
    # childcare
    if which_ben == hb
        if is_sparent

        end    
    end
    total = net_earn + other
    return LMTIncomes{T}(gross_earn,net_earn,total)
end

function calc_credits()

end

function calc_ESA()

end

function calc_HB()

end

function calc_JSA()

end

function calc_PC()

end

function calc_CTC()

end

function calc_NDDS()

end

function calc_LHA()

end

function calc_WTC()

end

function calc_legacy_means_tested_benefits(
    pers   :: Person,
    sys    :: LegacyMeansTestedBenefitSystem ) :: LMTResults

end

end # module LegacyMeansTestedBenefits
