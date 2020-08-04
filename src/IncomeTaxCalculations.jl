module IncomeTaxCalculations

import Dates
import Dates: Date, now, TimeType, Year
import Parameters: @with_kw

using ScottishTaxBenefitModel
using .Definitions
import .ModelHousehold: Person
import .STBParameters: IncomeTaxSys
import .GeneralTaxComponents: TaxResult, calctaxdue, RateBands, delete_thresholds_up_to, *
import .Utils: get_if_set

export calc_income_tax, old_enough_for_mca, apply_allowance, ITResult
export calculate_company_car_charge

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



## FIXME just use the dict..
function guess_car_percentage_2020_21( sys :: IncomeTaxSys, company_car_fuel_type :: Fuel_Type )
    return sys.company_car_charge_by_CO2_emissions[company_car_fuel_type]
end

function calculate_company_car_charge(
    pers   :: Person,
    sys    :: IncomeTaxSys,
    calculator :: Function = guess_car_percentage_2020_21 ) :: Real
    value = max(0.0, pers.company_car_value-
        pers.company_car_contribution )
    if pers.fuel_supplied > 0.0
        value += sys.fuel_imputation
    end
    prop = calculator( sys, pers.company_car_fuel_type )
    value * prop
end

# TODO pension contributions

function make_non_savings()::Incomes_Dict
    excl = union(Set(keys(DIVIDEND_INCOME)), Set( keys(SAVINGS_INCOME)))
    nsi = make_all_taxable()
    for i in excl
        delete!( nsi, i )
    end
    nsi
end

"""
Very rough approximation to MCA age - ignores all months since we don't have that in a typical dataset
TODO maybe overload this with age as a Date?
"""
function old_enough_for_mca(
    sys            :: IncomeTaxSys,
    age            :: Integer,
    model_run_date :: TimeType = now() ) :: Bool
    (model_run_date - Year(age)) < sys.mca_date
end

function calculate_allowance( pers::Person, sys :: IncomeTaxSys ) :: Real
    allowance = sys.personal_allowance
    if pers.registered_blind
        allowance += sys.blind_persons_allowance
    end
    allowance
end

function apply_allowance( allowance::Real, income::Real )::Tuple where RT<:Real
    r = max( 0.0, income - allowance )
    allowance = max(0.0, allowance-income)
    allowance,r
end

"""
  from Melville, ch13.
  Changes are in itres: add to pension fields and extend bands
  notes:
  Melville talks of "earned income" - using non-savings income
  FIXME: check: does the personal_allowance_income_limit get bumped up?
"""
function calculate_pension_taxation!(
    itres  ::ITResult,
    sys    :: IncomeTaxSys,
    pers   ::Person,
    total_income::Real,
    earned_income:: Real )

    itres.savings_thresholds = copy( sys.savings_thresholds )
    itres.dividend_thresholds = copy( sys.dividend_thresholds )
    itres.non_savings_thresholds = copy( sys.non_savings_thresholds )
    avc = get_if_set(pers.income, avcs, 0.0)
    pen = get_if_set(pers.income, pension_contributions, 0.0)
    eligible_contribs = avc + pen
    if eligible_contribs <= 0.0
        return
    end

    max_relief = sys.pension_contrib_annual_allowance
    if total_income < sys.pension_contrib_basic_amount
        max_relief = sys.pension_contrib_basic_amount
    end
    if total_income > sys.pension_contrib_threshold_income
        excess = total_income - sys.pension_contrib_threshold_income
        max_relief = max( sys.pension_contrib_annual_minimum,
            sys.pension_contrib_annual_allowance - excess*sys.pension_contrib_withdrawal_rate )
    end
    eligible_contribs = min( eligible_contribs, max_relief );
    itres.pension_eligible_for_relief = eligible_contribs
    basic_rate = sys.non_savings_rates[ sys.non_savings_basic_rate ]
    # println("total_income=$total_income max_relief=$max_relief eligible_contribs=$eligible_contribs basic_rate=$basic_rate sys.pension_contrib_withdrawal_rate=$(sys.pension_contrib_withdrawal_rate)")
    gross_contribs = eligible_contribs/(1-basic_rate)
    itres.pension_relief_at_source = gross_contribs - eligible_contribs
    itres.non_savings_thresholds .+= gross_contribs
    itres.savings_thresholds .+= gross_contribs
    itres.dividend_thresholds .+= gross_contribs

end

"""

Complete(??) income tax calculation, based on the Scottish/UK 2019 system.
Mostly taken from Melville (2019) chs 2-4.

FIXME this is too long and needs broken up.

problems:

1. we do this in strict non-savings, savings, dividends order; see 2(11) for examples where it's now advantageous to use a different order
2.

returns a single total tax liabilty, plus multiple intermediate numbers
in the `intermediate` dict

"""
function calc_income_tax(
    pers   :: Person{IT,RT},
    sys    :: IncomeTaxSys{IT,RT},
    spouse_transfer :: RT = 0.0 ) :: ITResult{RT} where IT<:Integer where RT<:Real
    itres = ITResult{RT}()
    total_income = sys.all_taxable*pers.income;
    non_savings = sys.non_savings_income*pers.income;
    savings = sys.savings_income*pers.income;
    dividends = sys.dividend_income*pers.income;

    allowance = calculate_allowance( pers, sys )
    # allowance reductions goes here

    non_dividends = non_savings + savings

    adjusted_net_income = total_income

    calculate_pension_taxation!( itres, sys, pers, total_income, non_savings )

    # adjusted_net_income -= itres.pension_eligible_for_relief

    adjusted_net_income += calculate_company_car_charge(pers, sys)
    # ...

    non_savings_tax = TaxResult(0.0, 0)
    savings_tax = TaxResult(0.0, 0)
    dividend_tax = TaxResult(0.0, 0)

    if adjusted_net_income > sys.personal_allowance_income_limit
        allowance =
            max(0.0,
                allowance -
                    sys.personal_allowance_withdrawal_rate*(
                        adjusted_net_income - sys.personal_allowance_income_limit ))
    end
    taxable_income = adjusted_net_income-allowance
    itres.intermediate["allowance"]=allowance
    itres.intermediate["total_income"]=total_income
    itres.intermediate["adjusted_net_income"]=adjusted_net_income
    itres.intermediate["taxable_income"]=taxable_income
    itres.intermediate["savings"]=savings
    itres.intermediate["non_savings"]=non_savings
    itres.intermediate["dividends"]=dividends
    # note: we copy from the expanded versions from pension_contributions
    savings_thresholds = deepcopy( itres.savings_thresholds )
    savings_rates = deepcopy( sys.savings_rates )
    # FIXME model all this with parameters
    toprate = size( savings_thresholds )[1]
    if taxable_income > 0
        allowance,non_savings_taxable = apply_allowance( allowance, non_savings )
        non_savings_tax = calctaxdue(
            taxable=non_savings_taxable,
            rates=sys.non_savings_rates,
            thresholds=itres.non_savings_thresholds )

        # horrific savings calculation see Melville Ch2 "Savings Income" & examples 2-3
        # FIXME Move to separate function
        # delete the starting bands up to non_savings taxabke icome
        savings_rates, savings_thresholds = delete_thresholds_up_to(
            rates=savings_rates,
            thresholds=savings_thresholds,
            upto=non_savings_taxable );
        if sys.personal_savings_allowance > 0
            psa = sys.personal_savings_allowance
            # println( "taxable income $taxable_income sys.savings_thresholds[2] $(sys.savings_thresholds[2])")
            if taxable_income > sys.savings_thresholds[toprate]
                psa = 0.0
            elseif taxable_income > sys.savings_thresholds[2] # above the basic rate
                psa *= 0.5 # FIXME parameterise this
            end
            if psa > 0.0 ## if we haven't deleted the zero band already, just widen it
                if savings_rates[1] == 0.0
                    savings_thresholds[1] += psa;
                else ## otherwise, insert a  new one.
                    savings_thresholds = vcat([psa], savings_thresholds )
                    savings_rates = vcat([0.0], savings_rates )
                end
            end
            itres.intermediate["personal_savings_allowance"] = psa
        end # we have a personal_savings_allowance
        itres.intermediate["savings_rates"] = savings_rates
        itres.intermediate["savings_thresholds"] = savings_thresholds
        allowance,savings_taxable = apply_allowance( allowance, savings )
        savings_tax = calctaxdue(
            taxable=savings_taxable,
            rates=savings_rates,
            thresholds=savings_thresholds )

        # Dividends
        # see around example 8-9 ch2
        allowance,dividends_taxable =
            apply_allowance( allowance, dividends )
        dividend_rates=deepcopy(sys.dividend_rates)
        dividend_thresholds=deepcopy(itres.dividend_thresholds )
        # always preserve any bottom zero rate
        add_back_zero_band = false
        zero_band = 0.0
        used_thresholds = non_savings_taxable+savings_taxable
        copy_start = 1
        # handle the zero rate
        if dividend_rates[1] == 0.0
            add_back_zero_band = true
            zero_band = dividend_thresholds[1]
            used_thresholds += min( zero_band, dividends_taxable )
            copy_start = 2
        end
        dividend_rates, dividend_thresholds =
            delete_thresholds_up_to(
                rates=dividend_rates[copy_start:end],
                thresholds=dividend_thresholds[copy_start:end],
                upto=used_thresholds );
        if add_back_zero_band
            dividend_rates = vcat( [0.0], dividend_rates )
            dividend_thresholds .+= zero_band # push all up
            dividend_thresholds = vcat( zero_band, dividend_thresholds )
        end
        itres.intermediate["dividend_rates"]=dividend_rates
        itres.intermediate["dividend_thresholds"]=dividend_thresholds
        itres.intermediate["add_back_zero_band"]=add_back_zero_band
        itres.intermediate["dividends_taxable"]=dividends_taxable

        dividend_tax = calctaxdue(
            taxable=dividends_taxable,
            rates=dividend_rates,
            thresholds=dividend_thresholds )
    else # some allowance left
        allowance = -taxable_income # e.g. allowance - taxable_income
    end
    itres.intermediate["non_savings_tax"]=non_savings_tax.due
    itres.intermediate["savings_tax"]=savings_tax.due
    itres.intermediate["dividend_tax"]=dividend_tax.due

    #
    # tax reducers
    #
    total_tax = non_savings_tax.due+savings_tax.due+dividend_tax.due
    if spouse_transfer > 0
        sp_reduction =
            sys.non_savings_rates[sys.non_savings_basic_rate]*spouse_transfer
        total_tax = max( 0.0, total_tax - sp_reduction )
    end
    itres.total_tax = total_tax
    itres.taxable_income = taxable_income
    itres.allowance = allowance
    itres.total_income = total_income
    itres.adjusted_net_income = adjusted_net_income
    itres.non_savings = non_savings_tax.due
    itres.non_savings_band = non_savings_tax.end_band
    itres.savings = savings_tax.due
    itres.savings_band = savings_tax.end_band
    itres.dividends = dividend_tax.due
    itres.dividend_band = dividend_tax.end_band
    itres.unused_allowance = allowance
    itres
end

function allowed_to_transfer_allowance(
    sys  :: IncomeTaxSys;
    from :: ITResult,
    to   :: ITResult ) :: Bool

   can_transfer :: Bool = true
   if ! (from.unused_allowance > 0.0 &&
         to.unused_allowance <= 0.0)
         # nothing to transfer - this is actually wrong since
         # you can opt to transfer some allowance even if you
         # can technically use it.
       can_transfer = false
   elseif to.savings_band > sys.savings_basic_rate ||
      to.non_savings_band > sys.non_savings_basic_rate ||
      to.dividend_band > sys.dividend_basic_rate
      can_transfer = false
   end
   ## TODO disallow if mca claimed
   can_transfer
end # can_transfer


function calculate_mca( pers :: Person, tax :: ITResult, sys :: IncomeTaxSys)::Real
    ## FIXME parameterise this
    mca = sys.married_couples_allowance
    if tax.adjusted_net_income > sys.mca_income_maximum
        mca = max( sys.mca_minimum, mca -
           (tax.adjusted_net_income-sys.mca_income_maximum)*sys.mca_withdrawal_rate)
    end
    mca * sys.mca_credit_rate
end

function calc_income_tax(
    head   :: Person{IT,RT},
    spouse :: Union{Nothing,Person{IT,RT}},
    sys    :: IncomeTaxSys{IT,RT} ) :: NamedTuple  where IT<:Integer where RT<:Real
    headtax = calc_income_tax( head, sys )
    spousetax = nothing
    # FIXME the transferable stuff here
    # is not right as you can elect to transfer more than
    # the surplus allowance in some cases.
    # also - add in restrictions on transferring to
    # higher rate payers.
    if spouse !== nothing
        spousetax = calc_income_tax( spouse, sys )
        # This is not quite right - you can't claim the
        # MCA AND transfer an allowance. We're assuming
        # always MCA first (I think it's always more valuable?)
        if old_enough_for_mca( sys, head.age ) || old_enough_for_mca( sys, spouse.age )
            # shoud usually just go to the head but.. some stuff about partner
            # with greater income if married after 2005 and you can elect to do this if
            # married before, so:
            if headtax.adjusted_net_income > spousetax.adjusted_net_income
                headtax.mca = calculate_mca( head, headtax, sys )
                headtax.total_tax = max( 0.0, headtax.total_tax - headtax.mca )
            else
                spousetax.mca = calculate_mca( spouse, spousetax, sys )
                spousetax.total_tax = max( 0.0, spousetax.total_tax - spousetax.mca )
            end
        end
        if spousetax.mca == 0.0 == headtax.mca
            if allowed_to_transfer_allowance( sys, from=spousetax, to=headtax )
                transferable_allow = min( spousetax.unused_allowance, sys.marriage_allowance )
                headtax = calc_income_tax( head, sys, transferable_allow )
                headtax.intermediate["transfer_spouse_to_head"] = transferable_allow
            elseif allowed_to_transfer_allowance( sys, from=headtax, to=spousetax )
                transferable_allow = min( headtax.unused_allowance, sys.marriage_allowance )
                spousetax = calc_income_tax( spouse, sys, transferable_allow )
                spousetax.intermediate["transfer_head_to_spouse"] = transferable_allow
            end
        end
    end
    ( head=headtax, spouse=spousetax )
end # calc_income_tax

end # module
