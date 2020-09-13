using ScottishTaxBenefitModel
using .FRSHouseholdGetter: initialise, get_household, get_num_households
using .STBParameters:
    TaxBenefitSystem,
    NationalInsuranceSys,
    IncomeTaxSys,
    weeklyise!
using .ModelHousehold: Household, Person
import .ExampleHouseholdGetter

# pids for example people
# see make_pid 
 const RUK_PERSON = 320190010101

 const SCOT_HEAD = 320190010201
 const SCOT_SPOUSE = 320190010202

function get_default_it_system(
   ;
  year     :: Integer=2019,
  scotland :: Bool = true,
  weekly   :: Bool = true )::Union{Nothing,IncomeTaxSys}
  it = nothing
  if year == 2019
     it = IncomeTaxSys{Float64}()
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

function init_data()
   nhh = get_num_households()
   num_people = -1
   if nhh == 0
      @time nhh, num_people,nhh2 = initialise(
            household_name = "model_households_scotland",
            people_name    = "model_people_scotland" )
   end
   (nhh,num_people)
end


function get_system(; scotland::Bool ) :: TaxBenefitSystem
    tb = TaxBenefitSystem{Float64}()
    weeklyise!(tb.ni)
    # overwrite IT to get RuK system as needed
    # println( itn )
    tb.it = get_default_it_system( year=2019, scotland=scotland, weekly=true )
    println( tb.it )
    tb
end

@enum SS_Examples cpl_w_2_kids_hh single_parent_hh single_hh childless_couple_hh

function get_ss_examples()::Dict{SS_Examples, Household}
    d = Dict{SS_Examples, Household}()
    @time names = ExampleHouseholdGetter.initialise()
    d[cpl_w_2_kids_hh] = ExampleHouseholdGetter.get_household( "example_hh1" )
    d[single_parent_hh] = ExampleHouseholdGetter.get_household( "single_parent_1" )
    d[single_hh] = ExampleHouseholdGetter.get_household( "example_hh2" )
    d[childless_couple_hh] = ExampleHouseholdGetter.get_household("mel_c2_scot") 
    return d
end

function unemploy!( pers::Person )
   pers.usual_hours_worked = 0
   pers.actual_hours_worked = 0
   pers.employment_status = Unemployed 
   delete!( pers.income, wages )  
   delete!( pers.income, self_employment_income )  
    
end

function employ!( pers::Person, wage=600.00 )
   pers.usual_hours_worked = 40
   pers.actual_hours_worked = 40
   pers.employment_status = Full_time_Employee 
   pers.income[wages] = wage   
end

function disable!( pers::Person )
   pers.employment_status = Permanently_sick_or_disabled
   pers.health_status = Bad
   pers.has_long_standing_illness = true
   pers.adls_are_reduced = reduced_a_lot
   pers.how_long_adls_reduced = v_12_months_or_more
   pers.disabilities[mobility] = true
   pers.disabilities[stamina] = true
end

function enable!( pers::Person )
   pers.health_status = Good
   pers.has_long_standing_illness = false
   pers.adls_are_reduced = not_reduced
   pers.how_long_adls_reduced = Missing_Illness_Length
   pers.disabilities = []
end

function blind!( pers :: Person )
   pers.disabilities[vision ] = true
   pers.registered_blind = true
end

function unblind!( pers :: Person )
   delete!(pers.disabilities, vision )
   pers.registered_blind = false
end

function deafen!( pers :: Person )
   pers.disabilities[ hearing ] = true
   pers.registered_deaf = true
end

function undeafen!( pers :: Person )
   delete!(pers.disabilities, hearing )
   pers.registered_deaf = false
end