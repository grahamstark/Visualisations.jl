module ModelHousehold

using Dates

using ScottishTaxBenefitModel
using .Definitions
using .Utils: has_non_z
using .Uprating: uprate, UPRATE_MAPPINGS

export Household, Person, People_Dict
export uprate!, equivalence_scale, oldest_person, default_bu_allocation
export get_benefit_units, num_people, get_head,get_spouse, printpids
export make_benefit_unit, is_lone_parent, is_carer, is_disabled, is_single

mutable struct Person{RT<:Real}
    hid::BigInt # == sernum
    pid::BigInt # == unique id (year * 100000)+
    pno:: Int # person number in household
    default_benefit_unit:: Int
    age:: Int

    sex::Sex
    ethnic_group::Ethnic_Group
    marital_status::Marital_Status
    highest_qualification::Qualification_Type

    sic::SIC_2007
    occupational_classification::Standard_Occupational_Classification
    public_or_private :: Employment_Sector
    principal_employment_type :: Employment_Type

    socio_economic_grouping::Socio_Economic_Group
    age_completed_full_time_education:: Int
    years_in_full_time_work:: Int
    employment_status::ILO_Employment
    actual_hours_worked::RT
    usual_hours_worked::RT

    income::Dict{Incomes_Type,RT}
    assets::Dict{Asset_Type,RT}
    # contracted_out_of_serps::Bool

    registered_blind::Bool
    registered_partially_sighted::Bool
    registered_deaf::Bool

    disabilities::Disability_Dict
    health_status::Health_Status

    has_long_standing_illness :: Bool
    adls_are_reduced :: ADLS_Inhibited
    how_long_adls_reduced :: Illness_Length

    relationships::Relationship_Dict
    relationship_to_hoh :: Relationship
    is_informal_carer::Bool
    receives_informal_care_from_non_householder::Bool
    hours_of_care_received::RT
    hours_of_care_given::RT
    #
    # Childcare fields; assigned to children
    #
    hours_of_childcare :: RT
    cost_of_childcare :: RT
    childcare_type :: Child_Care_Type
    employer_provides_child_care :: Bool

    company_car_fuel_type :: Fuel_Type
    company_car_value :: RT
    company_car_contribution :: RT
    fuel_supplied :: RT
end

People_Dict = Dict{BigInt,Person}
Pid_Array = Vector{BigInt}

mutable struct Household{RT<:Real}
    sequence:: Int # position in current generated dataset
    hid::BigInt
    interview_year:: Int
    interview_month:: Int
    quarter:: Int
    tenure::Tenure_Type
    region::Standard_Region
    ct_band::CT_Band
    council_tax::RT
    water_and_sewerage ::RT
    mortgage_payment::RT
    mortgage_interest::RT
    years_outstanding_on_mortgage:: Int
    mortgage_outstanding::RT
    year_house_bought:: Int
    gross_rent::RT # rentg Gross rent including Housing Benefit  or rent Net amount of last rent payment
    rent_includes_water_and_sewerage::Bool
    other_housing_charges::RT # rent Net amount of last rent payment
    gross_housing_costs::RT
    total_income::RT
    total_wealth::RT
    house_value::RT
    weight::RT
    people::People_Dict
end

function uprate!( pid :: BigInt, year::Integer, quarter::Integer, person :: Person )
    for (t,inc) in person.income
            person.income[t] = uprate( inc, year, quarter, UPRATE_MAPPINGS[t])
    end
    for (a,ass) in person.assets
            person.assets[a] = uprate( ass, year, quarter, UPRATE_MAPPINGS[a])
    end
    person.cost_of_childcare = uprate( person.cost_of_childcare, year, quarter, upr_earnings )
end

function uprate!( hh :: Household )

    hh.water_and_sewerage  = uprate( hh.water_and_sewerage , hh.interview_year, hh.quarter, upr_housing_rents )
    hh.mortgage_payment = uprate( hh.mortgage_payment, hh.interview_year, hh.quarter, upr_housing_oo )
    hh.mortgage_interest = uprate( hh.mortgage_interest, hh.interview_year, hh.quarter, upr_housing_oo )
    hh.mortgage_outstanding = uprate( hh.mortgage_outstanding, hh.interview_year, hh.quarter, upr_housing_oo )
    hh.gross_rent = uprate( hh.gross_rent, hh.interview_year, hh.quarter, upr_housing_rents )
    hh.other_housing_charges = uprate( hh.other_housing_charges, hh.interview_year, hh.quarter, upr_nominal_gdp )
    hh.gross_housing_costs = uprate( hh.gross_housing_costs, hh.interview_year, hh.quarter, upr_nominal_gdp )
    hh.total_income = uprate( hh.total_income, hh.interview_year, hh.quarter, upr_nominal_gdp )
    hh.total_wealth = uprate( hh.total_wealth, hh.interview_year, hh.quarter, upr_nominal_gdp )
    hh.house_value = uprate( hh.house_value, hh.interview_year, hh.quarter, upr_housing_oo )
    for (pid,person) in hh.people
        uprate!( pid, hh.interview_year, hh.quarter, person )
    end

end

function oldest_person( people :: People_Dict ) :: NamedTuple
    oldest = ( age=-999, pid=BigInt(0))
    for person in people
        if person.age > oldest.age
            oldest.age = person.age
            oldest.pid = person.pid
        end
    end
    oldest
end

function equivalence_scale( people :: People_Dict ) :: Dict{Equivalence_Scale_Type,Real}
    np = length(people)
    eqp = Vector{EQ_Person}()
    oldest_pid = oldest_person( people )
    for (pid,person) in people
        eqtype = eq_other_adult
        if pid == oldest_pid.pid
            eqtype = eq_head
        else
            if (person.age < 16) || (( person.age < 18 ) & ( person.employment_status in [Student,Other_Inactive]))
                eqtype = eq_dependent_child # needn't actually be dependent, of course
            elseif person.relationships[ oldest_pid.pid ] in [Spouse,Cohabitee,Civil_Partner]
                eqtype = eq_spouse_of_head
            else
                eqtype = eq_other_adult
            end
        end
        push!( eqp, EQ_Person( person.age, eqtype ))
    end
    get_equivalence_scales( eqp )
end

PeopleArray = Vector{Person}

struct BenefitUnit
    people :: People_Dict
    head :: BigInt
    spouse :: BigInt
    adults :: Pid_Array
    children :: Pid_Array
end


BenefitUnits = Vector{BenefitUnit}
BUAllocation = Vector{PeopleArray}


#
# This creates a array of references to each person in the houshold, broken into
# benefit units using the default FRS/EFS benefit unit number.
#
function default_bu_allocation( hh :: Household ) :: BUAllocation
    bua = BUAllocation()
    nbus = 0
    # how many bus
    for (pid,person) in hh.people
        nbus = max( nbus, person.default_benefit_unit )
    end
    ## create benefit units
    for buno in 1:nbus
        push!( bua, PeopleArray())
    end
    sz = size( bua )[1]
    ## allocate peobuallocationple to them
    for (pid,person) in hh.people
        pp = bua[person.default_benefit_unit]
        push!( pp, person )
    end
    ## sort people in each by pid
    for buno in 1:nbus
        sort!( bua[buno], lt=(left,right)->isless(right.age,left.age))
    end
    bua
end

"""

Create a benefit unit from an array of people
really only needed for some unit tests.

FIXME: don't use outside of tests! likely mess up children and spouses.

"""
function make_benefit_unit( 
    people :: PeopleArray, 
    head :: BigInt, 
    spouse:: BigInt = -1 ) :: BenefitUnit
    npeople = size( people )[1]
    pd = People_Dict()
    children = Pid_Array()
    adults = Pid_Array()
    push!( adults, head )
    if spouse > 0 
        push!( adults, spouse )
    end
    palloc = spouse <= 0 ? 2 : 3
    for n in palloc:npeople
        push!(children, people[n].pid)
        @assert people[n].age <= 21 # vague idiot check
    end
    for pers in people
        pd[pers.pid] = pers
        # println( "adding person $(pers.pid)")
    end
    return BenefitUnit( pd, head, spouse, adults, children )
end

#
# This creates a array of references to each person in the houshold, broken into
# benefit units using the default FRS/EFS benefit unit number.
#
function allocate_to_bus( bua :: BUAllocation ) :: BenefitUnits
    nbus = size(bua)[1]
    bus = BenefitUnits(undef, nbus)
    for i in 1:nbus
        people = People_Dict()
        head_pid :: BigInt = -1
        spouse_pid :: BigInt = -1
        children = Pid_Array()
        adults = Pid_Array()
        npeople = size( bua[i])[1]
        for p in 1:npeople
            person = bua[i][p]
            people[person.pid] = person
            if p == 1
                head_pid = person.pid
                push!( adults, head_pid )
            else
                # println( "on bu $i person $p relationships $(person.relationships)")
                reltohead = person.relationships[head_pid]
                if reltohead in [Spouse,Cohabitee,Civil_Partner]
                    spouse_pid = person.pid
                    push!( adults, spouse_pid )
                    # FIXME we need to remove these checks if
                    # we're using a non-default allocation to bus
                    # @assert person.age >= 16
                else
                    # @assert person.age <= 19
                    push!( children, person.pid )
                end
            end
        end
        new_bu = BenefitUnit( people, head_pid, spouse_pid, adults, children )
        bus[i] = new_bu
    end
    bus
end

function get_benefit_units(
    hh :: Household,
    allocator :: Function=default_bu_allocation ) :: BenefitUnits
    allocate_to_bus( allocator(hh))
end

function num_people( bu :: BenefitUnit )::Integer
    length( bu.people )
end

function num_people( hh :: Household ) :: Integer
    length( hh.people )
end

function get_head( bu :: BenefitUnit )::Person
    bu.people[bu.head]
end

function get_spouse( bu :: BenefitUnit )::Union{Nothing,Person}
    if bu.spouse <= 0
        return nothing
    end
    bu.people[bu.spouse]
end

function is_lone_parent( bu :: BenefitUnit ) :: Bool
    return bu.spouse < 0 && size( bu.children )[1] > 0
end

#
# fixme just count people???
#
function is_lone_parent( hh :: Household,
    allocator :: Function=default_bu_allocation ) :: Bool
    
    bus = get_benefit_units( hh, allocator )
    if size(bus)[1] > 1
        return false
    end
    return bus[1].spouse < 0 && size( bus[1].children )[1] > 0
end


function is_single( bu :: BenefitUnit ) :: Bool
    num_people( bu ) == 1
end

function is_single( hh :: Household ) :: Bool
    num_people( hh ) == 1
end

"""
FIXME we're going to do this solely on benefit receipt
for now until we get the regressions done
we use historic benefits here since this uses actual data
"""
function pers_is_carer( pers :: Person ) :: Bool
    has_non_z( pers.income, carers_allowance )
end

const DISABLE_BENEFITS = [
    severe_disability_allowance,
    attendence_allowance,
    incapacity_benefit,
    dlaself_care,
    dlamobility,
    personal_independence_payment_daily_living,
    personal_independence_payment_mobility]


"""
FIXME we're going to do this solely on benefit receipt
for now until we get the regressions done
we use historic benefits here since this uses actual data
"""
function pers_is_disabled( pers :: Person ) :: Bool
    if pers.registered_blind
        return true
    end
    for k in DISABLE_BENEFITS
        if has_non_z( pers.income, k )
            return true
        end
    end # loop
    return false
end

function search( people :: People_Dict, func :: Function ) :: Bool
    for ( pid,pers ) in people
        if func( pers )
            return true
        end
    end
    return false
end

function search( bu :: BenefitUnit, func :: Function ) :: Bool
    return search( bu.people, func )
end

function search( hh :: Household, func :: Function ) :: Bool
    return search( hh.people, func )
end

function is_disabled( bu :: BenefitUnit ) :: Bool
    search( bu.people, pers_is_disabled )
end

function is_disabled( hh :: Household ) :: Bool
    search( hh.people, pers_is_disabled )
end

function is_carer( bu :: BenefitUnit ) :: Bool
    search( bu.people, pers_is_carer )
end

function is_carer( hh :: Household ) :: Bool
    search( hh.people, pers_is_carer )
end


# simple diagnostic prints for testing allocation

function printpids( pers :: Person )
    println( "pid: $(pers.pid) age $(pers.age) sex $(pers.sex) default_benefit_unit $(pers.default_benefit_unit) ")
end

function printpids( bu::BenefitUnit)
      head = get_head( bu )
      print( "HEAD: ")
      printpids( head )
      spouse = get_spouse( bu )
      if spouse !== nothing
            print( "SPOUSE: ")
            printpids( spouse )

      end
      for chno in bu.children
            print( "CHILD_$(chno):")
            child = bu.people[chno]
            printpids( child )
      end
end

function printpids( people :: People_Dict )
    ks = sort(collect(keys(people)))
    for k in ks
        print( "PERSON_$k")
        printpids( people[k] )
    end
end

function printpids( buas::BUAllocation )
    nbus = size( buas )[1]
    for i in 1:nbus
        npeople = size( buas[i] )[1]
        println( "bu[$i]; num_people = $npeople:")
        for p in 1:npeople
            print( "PERS_$(p): ")
            printpids( buas[i][p])
        end
    end
end

end # module
