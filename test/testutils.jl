using ScottishTaxBenefitModel
using .FRSHouseholdGetter: initialise, get_household, get_num_households
using .STBParameters:
    TaxBenefitSystem,
    NationalInsuranceSys,
    IncomeTaxSys,
    weeklyise!
using .ModelHousehold: Household, BenefitUnit, Person, num_children
using .Definitions
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

function to_nearest_p( x, y :: Real ) :: Bool
    round(x, digits=2) == round(y, digits=2)
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
    weeklyise!(tb)
    # overwrite IT to get RuK system as needed
    # println( itn )
    tb.it = get_default_it_system( year=2019, scotland=scotland, weekly=true )
    return tb
end

@enum SS_Examples cpl_w_2_children_hh single_parent_hh single_hh childless_couple_hh

function get_ss_examples()::Dict{SS_Examples, Household}
    d = Dict{SS_Examples, Household}()
    @time names = ExampleHouseholdGetter.initialise()
    d[cpl_w_2_children_hh] = ExampleHouseholdGetter.get_household( "example_hh1" )
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

function disable_slightly!( pers::Person )
   pers.employment_status = Permanently_sick_or_disabled
   pers.health_status = Bad
   pers.has_long_standing_illness = true
   pers.adls_are_reduced = reduced_a_little
   pers.how_long_adls_reduced = v_12_months_or_more
   pers.disabilities[mobility] = true
   pers.disabilities[stamina] = true
end

function disable_seriously!( pers::Person )
   pers.employment_status = Permanently_sick_or_disabled
   pers.health_status = Very_Bad
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
   pers.disabilities = Disability_Dict{Bool}()
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

function carer!( pers :: Person )
   pers.income[carers_allowance] = 100.0
   pers.is_informal_carer = true
   pers.hours_of_care_given = 10
   pers.employment_status = Looking_after_family_or_home
end

function uncarer!( pers :: Person )
   delete!(pers.income,carers_allowance)
   pers.is_informal_carer = false
   pers.hours_of_care_given = 0
end

function retire!( pers :: Person )
   pers.usual_hours_worked = 0
   pers.employment_status = Retired
end


function add_child!( bu :: BenefitUnit, age :: Integer, sex :: Sex )::BigInt
    nc = num_children( bu )
    @assert nc > 0
    np = deepcopy( bu.people[bu.children[1]] )
    np.pid = maximum( bu.children ) + 1
    np.age = age
    np.sex = sex
    bu.people[np.pid] = np
    push!( bu.children, np.pid )
    @assert num_children( bu ) == nc+1
    return np.pid
end

function delete_child!( bu :: BenefitUnit, pid :: BigInt )
    delete!( bu.people, pid )
    pos :: BigInt = -1
    nc = size(bu.children)[1]
    for p in 1:nc
        if bu.childreen[p] == pid
            deleteat![p]
            break;fam
        end
    end
end

"""
Extract a household from 
"""
function spreadsheet_ss_example( key :: String ) :: NamedTuple
    # B_1	B_2	B_3	B_4	B_5	B_6	B7	K3_1	K3_2	K3_3	SP_1	SP_2	SP_3	2C_1	2C_2	2C_3	2C_4	SE2_1	2E_1	2E_2	CC_SE-1	CC_SE-2	CC_SE-3	DC_1	DC_2	DC_3	DA_1	DA_2	DA_3	CL_1	CL_2	CL_3
    re = r"([A-Z0-9]+)_(.*)"        
    m = match( re, key )
    fam = m[1]
    n = m[2]
    examples = get_ss_examples()
    name = ""
    hh = nothing
    rent = 600/4
    ct = 123.25/4
    if fam == "B"
        name = "Basic Case; "
        hh = examples[cpl_w_2_children_hh]
        bu = get_benefit_units(cplhh)[1]
        spouse = get_spouse( bu )
        head = get_head( bu ) 
        head.age = 40
        head.usual_hours_worked = 40
        incs = [
        "1"= 7000.00,
        "2" = 4,000.00	12,000.00	17,000.00	22,000.00	30,000.00	50,000.00
            head.income[wages]=7_000.00/52.0
            
    elseif fam == "K3"
        name = "3 Kids; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "SP"
        name = "Single Parent; "
        hh = examples[single_parent_hh]
    elseif fam == "SE2"
        name = "Single Earner; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "2C"
        name = "Basic; 2 child limit test; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "2E"
        name = "2 Earner; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "CC"
        name = "Child Care; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "DC"
        name = "Disabled Child; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "DA" 
        name = "Disabled Adult; "
        hh = examples[cpl_w_2_children_hh]
    elseif fam == "CL"
        name = "Childless; "
        hh = examples[childless_couple_hh]
    else
        error( "unknown key $fam " )
    end
    hh.gross_rent = rent
    hh.council_tax = ct
    return ( name=name, hh=hh )
end

