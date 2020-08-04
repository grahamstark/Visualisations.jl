module Results

    using Parameters: @with_kw
    using DataFrames

    using ScottishTaxBenefitModel
    using .Definitions
    using .ModelHousehold: Household, BenefitUnits, get_benefit_units
    using .GeneralTaxComponents: RateBands
    
    export 
        ITResult,
        NIResult,
        IndividualResult,
        BenefitUnitResult,
        HouseholdResult,
        init_household_result


        @with_kw mutable struct NIResult{RT<:Real}
            above_lower_earnings_limit :: Bool = false
            total_ni :: RT = 0.0
            class_1_primary    :: RT = 0.0
            class_1_secondary  :: RT = 0.0
            class_2   :: RT = 0.0
            class_3   :: RT = 0.0
            class_4   :: RT = 0.0
            assumed_gross_wage :: RT = 0.0
        end

        @with_kw mutable struct ITResult{RT<:Real}
            total_tax :: RT = 0.0
            taxable_income :: RT = 0.0
            adjusted_net_income :: RT = 0.0
            total_income :: RT = 0.0
            non_savings :: RT = 0.0
            allowance   :: RT = 0.0
            non_savings_band :: Integer = 0
            savings :: RT = 0.0
            savings_band :: Integer = 0
            dividends :: RT = 0.0
            dividend_band :: Integer = 0
            unused_allowance :: RT = 0.0
            mca :: RT = 0.0
            transferred_allowance :: RT = 0.0
            pension_eligible_for_relief :: RT = 0.0
            pension_relief_at_source :: RT = 0.0
            non_savings_thresholds :: RateBands = zeros(RT,0)
            savings_thresholds  :: RateBands = zeros(RT,0)
            dividend_thresholds :: RateBands = zeros(RT,0)
            intermediate :: Dict = Dict()
        end
        

    @with_kw mutable struct IndividualResult{RT<:Real}
       eq_scale  :: RT = zero(RT)
       net_income :: RT =zero(RT)

       ni = NIResult{RT}()
       it = ITResult{RT}()
       income_taxes :: RT = zero(RT)
       means_tested_benefits :: RT = zero(RT)
       other_benefits  :: RT = zero(RT)
       incomes = Dict{Incomes_Type,RT}()
       # ...
    end

    @with_kw mutable struct BenefitUnitResult{RT<:Real}
        eq_scale  :: RT = zero(RT)
        net_income    :: RT = zero(RT)
        eq_net_income :: RT = zero(RT)
        income_taxes :: RT = zero(RT)
        means_tested_benefits :: RT = zero(RT)
        other_benefits  :: RT = zero(RT)
        pers          = Dict{BigInt,IndividualResult{RT}}()
    end

    @with_kw mutable struct HouseholdResult{RT<:Real}
        eq_scale  :: RT = zero(RT)
        bhc_net_income :: RT = zero(RT)
        eq_bhc_net_income :: RT = zero(RT)
        ahc_net_income :: RT = zero(RT)
        eq_ahc_net_income :: RT = zero(RT)
        net_housing_costs :: RT = zero(RT)
        income_taxes :: RT = zero(RT)
        means_tested_benefits :: RT = zero(RT)
        other_benefits  :: RT = zero(RT)
        bus = Vector{BenefitUnitResult{RT}}(undef,0)
    end

    # create results that mirror some
    # allocation of people to benefit units
    function init_household_result( hh :: Household{IT,RT} ) :: HouseholdResult{RT} where IT <: Integer where RT <: Real
        bus = get_benefit_units(hh)
        hr = HouseholdResult{RT}()
        for bu in bus
            bur = BenefitUnitResult{RT}()
            for pid in keys( bu.people )
                # println( "pid=$pid")
                bur.pers[pid] = IndividualResult{RT}()
            end
            push!( hr.bus, bur )
        end
        return hr
    end

    function aggregate( hhr :: HouseholdResult )


    end


end
