module STBParameters

    import Dates
    import Dates: Date, now, TimeType, Year

    using Parameters
    import JSON
    # import JSON2
    import BudgetConstraints: BudgetConstraint

    import ScottishTaxBenefitModel: GeneralTaxComponents, Definitions, Utils
    import .GeneralTaxComponents: RateBands, WEEKS_PER_YEAR
    using .Definitions
    import .Utils


    export IncomeTaxSys, NationalInsuranceSys, TaxBenefitSystem
    export weeklyise!, annualise!, fromJSON, get_default_it_system
    export MCA_DATE

    const MCA_DATE = Date(1935,4,6) # fixme make this a parameter

    const SAVINGS_INCOME = Incomes_Dict(
       bank_interest => 1.0,
       bonds_and_gilts => 1.0,
       other_investment_income => 1.0
   )

   const DIVIDEND_INCOME = Incomes_Dict(
       stocks_shares => 1.0
   )
   const Exempt_Income = Incomes_Dict(
       individual_savings_account=>1.0,
       local_taxes=>1.0,
       free_school_meals => 1.0,
       dlaself_care => 1.0,
       dlamobility => 1.0,
       child_benefit => 1.0,
       pension_credit => 1.0,
       bereavement_allowance_or_widowed_parents_allowance_or_bereavement=> 1.0,
       armed_forces_compensation_scheme => 1.0, # FIXME not in my list check this
       war_widows_or_widowers_pension => 1.0,
       severe_disability_allowance => 1.0,
       attendence_allowance => 1.0,
       industrial_injury_disablement_benefit => 1.0,
       employment_and_support_allowance => 1.0,
       incapacity_benefit => 1.0,## taxable after 29 weeks,
       income_support => 1.0,
       maternity_allowance => 1.0,
       maternity_grant_from_social_fund => 1.0,
       funeral_grant_from_social_fund => 1.0,
       guardians_allowance => 1.0,
       winter_fuel_payments => 1.0,
       dwp_third_party_payments_is_or_pc => 1.0,
       dwp_third_party_payments_jsa_or_esa => 1.0,
       extended_hb => 1.0,
       working_tax_credit => 1.0,
       child_tax_credit => 1.0,
       working_tax_credit_lump_sum => 1.0,
       child_tax_credit_lump_sum => 1.0,
       housing_benefit => 1.0,
       universal_credit => 1.0,
       personal_independence_payment_daily_living => 1.0,
       personal_independence_payment_mobility => 1.0 )

   function make_all_taxable()::Incomes_Dict
       eis = union(Set( keys( Exempt_Income )), Definitions.Expenses )
       all_t = Incomes_Dict()
       for i in instances(Incomes_Type)
           if ! (i ∈ eis )
               all_t[i]=1.0
           end
       end
       all_t
   end

    function make_non_savings()::Incomes_Dict
       excl = union(Set(keys(DIVIDEND_INCOME)), Set( keys(SAVINGS_INCOME)))
       nsi = make_all_taxable()
       for i in excl
           delete!( nsi, i )
       end
       nsi
    end

   ## TODO Use Unitful to have currency weekly monthly annual counts as annotations
   # using Unitful

   Default_Fuel_Dict_2020_21 = Dict{Fuel_Type,Real}(
         Missing_Fuel_Type=>0.1,
         No_Fuel=>0.1,
         Other=>0.1,
         Dont_know=>0.1,
         Petrol=>0.25, # dunno
         Diesel=>0.37,
         Hybrid_use_a_combination_of_petrol_and_electricity=>0.16,
         Electric=>0.02,
         LPG=>0.02,
         Biofuel_eg_E85_fuel=>0.02 )

   @with_kw mutable struct IncomeTaxSys{IT<:Integer, RT<:Real}
      non_savings_rates :: RateBands{RT} =  [19.0,20.0,21.0,41.0,46.0]
      non_savings_thresholds :: RateBands{RT} =  [2_049.0, 12_444.0, 30_930.0, 150_000.0]
      non_savings_basic_rate :: IT = 2 # above this counts as higher rate

      savings_rates  :: RateBands{RT} =  [0.0, 20.0, 40.0, 45.0]
      savings_thresholds  :: RateBands{RT} =  [5_000.0, 37_500.0, 150_000.0]
      savings_basic_rate :: IT = 2 # above this counts as higher rate

      dividend_rates :: RateBands{RT} =  [0.0, 7.5,32.5,38.1]
      dividend_thresholds :: RateBands{RT} =  [2_000.0, 37_500.0, 150_000.0]
      dividend_basic_rate :: IT = 2 # above this counts as higher rate

      personal_allowance :: RT          = 12_500.00
      personal_allowance_income_limit :: RT = 100_000.00
      personal_allowance_withdrawal_rate  :: RT= 50.0
      blind_persons_allowance    :: RT  = 2_450.00

      married_couples_allowance   :: RT = 8_915.00
      mca_minimum                 :: RT = 3_450.00
      mca_income_maximum          :: RT = 29_600.00
      mca_credit_rate             :: RT = 10.0
      mca_withdrawal_rate         :: RT= 50.0

      marriage_allowance          :: RT = 1_250.00
      personal_savings_allowance  :: RT = 1_000.00

      # FIXME better to have it straight from
      # the book with charges per CO2 range
      # and the data being an estimate of CO2 per type
      company_car_charge_by_CO2_emissions :: Dict{ Fuel_Type, RT } = Default_Fuel_Dict_2020_21
      fuel_imputation  :: RT = 24_100.00

      #
      # pensions
      #
      pension_contrib_basic_amount :: RT = 3_600.00
      pension_contrib_annual_allowance :: RT = 40_000.00
      pension_contrib_annual_minimum :: RT = 10_000.00
      pension_contrib_threshold_income :: RT = 150_000.00
      pension_contrib_withdrawal_rate :: RT = 50.0

      non_savings_income :: Dict{Incomes_Type,RT}= make_non_savings()
      all_taxable :: Dict{Incomes_Type,RT} = make_all_taxable()
      savings_income :: Dict{Incomes_Type,RT} = SAVINGS_INCOME
      dividend_income :: Dict{Incomes_Type,RT} = DIVIDEND_INCOME
      mca_date = MCA_DATE

   end

   function annualise!( it :: IncomeTaxSys )
      it.non_savings_rates .*= 100.0
      it.savings_rates .*= 100.0
      it.dividend_rates .*= 100.0
      it.personal_allowance_withdrawal_rate *= 100.0
      it.non_savings_thresholds .*= WEEKS_PER_YEAR
      it.savings_thresholds .*= WEEKS_PER_YEAR
      it.dividend_thresholds .*= WEEKS_PER_YEAR
      it.personal_allowance *= WEEKS_PER_YEAR
      it.blind_persons_allowance *= WEEKS_PER_YEAR
      it.married_couples_allowance *= WEEKS_PER_YEAR
      it.mca_minimum *= WEEKS_PER_YEAR
      it.marriage_allowance *= WEEKS_PER_YEAR
      it.personal_savings_allowance *= WEEKS_PER_YEAR
      it.pension_contrib_basic_amount *= WEEKS_PER_YEAR


      it.mca_income_maximum       *= WEEKS_PER_YEAR
      it.mca_credit_rate             *= 100.0
      it.mca_withdrawal_rate         *= 100.0
      for k in it.company_car_charge_by_CO2_emissions
         it.company_car_charge_by_CO2_emissions[k.first] *= WEEKS_PER_YEAR
      end
      it.pension_contrib_basic_amount *= WEEKS_PER_YEAR
      it.pension_contrib_annual_allowance *= WEEKS_PER_YEAR
      it.pension_contrib_annual_minimum *= WEEKS_PER_YEAR
      it.pension_contrib_threshold_income *= WEEKS_PER_YEAR
      it.pension_contrib_withdrawal_rate *= 100.0
   end

   function weeklyise!( it :: IncomeTaxSys )

      it.non_savings_rates ./= 100.0
      it.savings_rates ./= 100.0
      it.dividend_rates ./= 100.0
      it.personal_allowance_withdrawal_rate /= 100.0
      it.non_savings_thresholds ./= WEEKS_PER_YEAR
      it.savings_thresholds ./= WEEKS_PER_YEAR
      it.dividend_thresholds ./= WEEKS_PER_YEAR
      it.personal_allowance /= WEEKS_PER_YEAR
      it.blind_persons_allowance /= WEEKS_PER_YEAR
      it.married_couples_allowance /= WEEKS_PER_YEAR
      it.mca_minimum /= WEEKS_PER_YEAR
      it.marriage_allowance /= WEEKS_PER_YEAR
      it.personal_savings_allowance /= WEEKS_PER_YEAR
      it.mca_income_maximum       /= WEEKS_PER_YEAR
      it.mca_credit_rate             /= 100.0
      it.mca_withdrawal_rate         /= 100.0
      for k in it.company_car_charge_by_CO2_emissions
         it.company_car_charge_by_CO2_emissions[k.first] /= WEEKS_PER_YEAR
      end
      it.pension_contrib_basic_amount /= WEEKS_PER_YEAR
      it.pension_contrib_annual_allowance /= WEEKS_PER_YEAR
      it.pension_contrib_annual_minimum /= WEEKS_PER_YEAR
      it.pension_contrib_threshold_income /= WEEKS_PER_YEAR
      it.pension_contrib_withdrawal_rate /= 100.0
   end

   function get_default_it_system(
      ;
      year     :: Integer=2019,
      scotland :: Bool = true,
      weekly   :: Bool = true )::Union{Nothing,IncomeTaxSys}
      it = nothing
      if year == 2019
         it = IncomeTaxSys{Int64,Float64}()
         if ! scotland
            it.non_savings_rates = [20.0,40.0,45.0]
            it.non_savings_thresholds = [37_500, 150_000.0]
            it.non_savings_basic_rate = 1
         end
         if weekly
            weeklyise!( it )
         end
      end
      it
   end

   function to_rate_bands( a :: Vector ) :: RateBands
      n = size( a )[1]
      rb :: RateBands{RT} =  zeros(n)
      for i in 1:n
         rb[i] =  Real(a[i])
      end
      rb
   end

   function to_fuel_charges( d :: Dict ) :: Fuel_Dict
      fd = Fuel_Dict()
      for i in instances(Fuel_Type)
         k = String(Symbol(i))
         fd[i] = d[k]
      end
      fd
   end

   """
   Map from
   """
   function fromJSON( json :: Dict ) :: IncomeTaxSys
      it = IncomeTaxSys()
      println( typeof(json["non_savings_thresholds"]))
      it.non_savings_rates = to_rate_bands( json["non_savings_rates"] )
      it.non_savings_thresholds  = to_rate_bands( json["non_savings_thresholds"] )
      it.non_savings_basic_rate = json["non_savings_basic_rate"]

      it.savings_rates = to_rate_bands( json["savings_rates"] )
      it.savings_thresholds = to_rate_bands( json["savings_thresholds"] )
      it.savings_basic_rate = json["savings_basic_rate"]

      it.dividend_rates = to_rate_bands( json["dividend_rates"] )
      it.non_savings_thresholds = to_rate_bands( json["non_savings_thresholds"] )
      it.dividend_basic_rate = json["dividend_basic_rate"]

      it.savings_thresholds = to_rate_bands( json["savings_thresholds"] )
      it.dividend_thresholds = to_rate_bands( json["dividend_thresholds"] )
      it.personal_allowance = json["personal_allowance"]
      it.personal_allowance_income_limit = json["personal_allowance_income_limit"]
      it.personal_allowance_withdrawal_rate = json["personal_allowance_withdrawal_rate"]
      it.blind_persons_allowance = json["blind_persons_allowance"]
      it.married_couples_allowance = json["married_couples_allowance"]
      it.mca_minimum = json["mca_minimum"]
      it.marriage_allowance = json["marriage_allowance"]
      it.personal_savings_allowance = json["personal_savings_allowance"]

      it.mca_income_maximum = json["mca_income_maximum"]
      it.mca_credit_rate = json["mca_credit_rate"]
      it.mca_withdrawal_rate = json["mca_withdrawal_rate"]
      ## CAREFUL!
      it.fuel_imputation = json["fuel_imputation"]
      it.company_car_charge_by_CO2_emissions =
         to_fuel_charges(json["company_car_charge_by_CO2_emissions"])
      it.pension_contrib_basic_amount = json["pension_contrib_basic_amount"]
      it.pension_contrib_annual_allowance = json["pension_contrib_annual_allowance"]
      it.pension_contrib_annual_minimum = json["pension_contrib_annual_allowance"]
      it.pension_contrib_threshold_income = json["pension_contrib_threshold_income"]
      it.pension_contrib_withdrawal_rate = json["pension_contrib_withdrawal_rate"]
      it
   end



   @with_kw mutable struct NationalInsuranceSys{IT<:Integer, RT<:Real}
      primary_class_1_rates :: RateBands{RT} = [0.0, 0.0, 12.0, 2.0 ]
      primary_class_1_bands :: RateBands{RT} = [118.0, 166.0, 962.0, 99999999999.99 ]
      secondary_class_1_rates :: RateBands{RT} = [0.0, 13.8, 13.8 ] # keep 2 so
      secondary_class_1_bands :: RateBands{RT} = [166.0, 962.0, 99999999999.99 ]
      state_pension_age :: IT = 66; # fixme move
      class_2_threshold ::RT = 6_365.0;
      class_2_rate ::RT = 3.00;
      class_4_rates :: RateBands{RT} = [0.0, 9.0, 2.0 ]
      class_4_bands :: RateBands{RT} = [8_632.0, 50_000.0, 9999999999999.99 ]
      ## some modelling of u21s and u25s in apprentiships here..
      # gross_to_net_lookup = BudgetConstraint(undef,0)
   end

   function weeklyise!( ni :: NationalInsuranceSys )
      ni.primary_class_1_rates ./= 100.0
      ni.secondary_class_1_rates ./= 100.0
      ni.class_2_threshold /= WEEKS_PER_YEAR
      ni.class_4_rates ./= 100.0
      ni.class_4_bands ./= WEEKS_PER_YEAR
   end

   @with_kw mutable struct LegacyMeansTestedBenefitSystem{IT<:Integer, RT<:Real}
       personal_allowances :: Dict{PersonalAllowanceType, RT} = Dict(
         pa_age_18_24 => 1,
         pa_age_25_and_over => 2,
         pa_age_18_and_in_work_activity => 3,
         pa_over_pension_age => 4,
         pa_lone_parent => 5,
         pa_lone_parent_over_pension_age => 6,
         pa_couple_both_over_18 => 7,
         pa_couple_over_pension_age => 8,
         pa_couple_one_over_18_high => 9,
         pa_couple_one_over_18_med => 10,
         pa_couple_one_over_18_low => 11 )

   end

   function fromJSON( json :: Dict ) :: NationalInsuranceSys
      ni = NationalInsuranceSys()
      ni.class_2_threshold = json["class_2_threshold"]
      ni.class_2_rate = json["class_2_rate"]
      ni.state_pension_age = json["state_pension_age"] # fixme move
      ni.primary_class_1_rates = to_rate_bands( json["primary_class_1_rates"] )
      ni.secondary_class_1_rates = to_rate_bands( json["secondary_class_1_rates"] )
      ni.primary_class_1_bands = to_rate_bands( json["primary_class_1_bands"] )
      ni.secondary_class_1_bands = to_rate_bands( json["secondary_class_1_bands"] )
      ni.class_4_rates = to_rate_bands( json["class_4_rates"] )
      ni.class_4_bands = to_rate_bands( json["class_4_bands"] )
      return ni
   end

   @with_kw mutable struct TaxBenefitSystem{IT<:Integer, RT<:Real}
      name :: AbstractString = "Scotland 2919/20"
      it   :: IncomeTaxSys = IncomeTaxSys{IT,RT}()
      ni   :: NationalInsuranceSys = NationalInsuranceSys{IT,RT}()
   end

   function save( filename :: AbstractString, sys :: TaxBenefitSystem )
       JSON.print( filename, sys )
   end


   # include( "../default_params/default2019_20.jl")
   # defsys = load()



end
