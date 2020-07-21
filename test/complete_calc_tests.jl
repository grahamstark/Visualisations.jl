using Test
using ScottishTaxBenefitModel
import ScottishTaxBenefitModel.ModelHousehold:
    Household,
    Person,
    People_Dict,
    default_bu_allocation,
    get_benefit_units
# import FRSHouseholdGetter
import ScottishTaxBenefitModel.ExampleHouseholdGetter
using ScottishTaxBenefitModel.Definitions
import Dates: Date
import ScottishTaxBenefitModel.STBParameters: TaxBenefitSystem, IncomeTaxSys, get_default_it_system
import ScottishTaxBenefitModel.SingleHouseholdCalculations:do_one_calc
using ScottishTaxBenefitModel.Results:
    IndividualResult,
    BenefitUnitResult,
    HouseholdResult,
    init_household_result

function get_tax(; scotland = false ) :: IncomeTaxSys
    it = get_default_it_system( year=2019, scotland=scotland, weekly=false )
    it.non_savings_rates ./= 100.0
    it.savings_rates ./= 100.0
    it.dividend_rates ./= 100.0
    it.personal_allowance_withdrawal_rate /= 100.0
    it.mca_credit_rate /= 100.0
    it.mca_withdrawal_rate /= 100.0
    it.pension_contrib_withdrawal_rate /= 100.0

    it
end

function hh_to_hhr_mismatch( hh :: Household, hhr :: HouseholdResult ) :: Bool
    bus = get_benefit_units( hh )
    if length(hhr.bus) != size( bus )[1]
        return true
    end
    buno = 1
    for bu in bus
        if length(hhr.bus[buno].pers) == length(bu.people)
            return true
        end
        buno += 1
    end
    false
end

# examples from https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/812844/Income_Tax_Liabilities_Statistics_June_2019.pdf
# table 2
@testset "Reproduce HMRC 2019/20" begin
    hh = ExampleHouseholdGetter.get_household( "mel_c2" )
    hhr = init_household_result( hh )
    @test hh_to_hhr_mismatch( hh, hhr )
end
