"""
Retrieve one of the model's example households & overwrite a few fields
to make things simpler.
"""
function make_hh( 
	;
	tenure              :: Tenure_Type = Private_Rented_Unfurnished,
	bedrooms            :: Int = 2, 
	hcost               :: Real = 100.0, 
	marrstat            :: Marital_Status = Single, 
	chu5                :: Integer = 0, 
	ch5p                :: Integer = 0,
	head_earn           :: Real = 0.0,
	head_hours          :: Real = 0.0,
	head_age            :: Int = 25,
	head_private_pens   :: Real = 0.0,
	spouse_earn         :: Real = 0.0,
	spouse_hours        :: Real = 0.0,
	spouse_age          :: Int = 0,
	spouse_private_pens :: Real = 0.0 ) :: Household
	hh = deepcopy(get_example( single_hh ))
	head = get_head(hh)
	head.age = head_age
	head.marital_status = marrstat
	empty!(head.income)
	head.income[wages] = head_earn
	head.income[private_pensions] = head_private_pens
	head.employment_status = if head_age > 66
		Retired 
		else
			if head_hours == 0
				Unemployed
			elseif head_hours < 20
				Part_time_Employee
			else
				Full_time_Employee
			end
		end
    head.actual_hours_worked = head.usual_hours_worked = head_hours
	enable!(head) # clear dla stuff from example
	hh.tenure = tenure
	hh.bedrooms = bedrooms
	hh.other_housing_charges = hh.water_and_sewerage = 0
	if hh.tenure == Mortgaged_Or_Shared
		hh.mortgage_payment = hcost
		hh.mortgage_interest = hcost
		hh.gross_rent = 0
	else
		hh.mortgage_payment = 0
		hh.mortgage_interest = 0
		hh.gross_rent = hcost
	end

	if marrstat in[Married_or_Civil_Partnership, Cohabiting]
		sex = head.sex == Male ? Female : Male # hetero ..
		add_spouse!( hh, spouse_age, sex )
		sp = get_spouse(hh)
		enable!(sp)
		sp.marital_status = marrstat
		empty!(sp.income)
		sp.income[wages] = spouse_earn
		sp.income[private_pensions] = spouse_private_pens
		sp.employment_status = if spouse_age > 66
			Retired 
			else
				if spouse_hours == 0
					(chu5+ch5p) > 0 ? Looking_after_family_or_home : Unemployed
				elseif spouse_hours < 20
					Part_time_Employee
				else
					Full_time_Employee
				end
			end
		sp.actual_hours_worked = sp.usual_hours_worked = spouse_hours
	end
	age = 0
	for ch in 1:chu5
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	age = 7
	for ch in 1:ch5p
		sex = ch % 1 == 0 ? Male : Female
		age += 1
		add_child!( hh, age, sex )
	end
	# set_wage!( head, 0, 10 )
	return hh
end

struct ExampleHH 
	picture :: String 
	label :: String
	description :: String
	hh :: Household 
end

const EXAMPLE_HHS = [
		ExampleHH("family1","Single Person, £25k", "Single female, aged 25, earning £25,000",
			make_hh(
				head_earn = 25_000/WEEKS_PER_YEAR,
				head_hours = 40 )),
		ExampleHH("family2","Single Parent, £25k", "Working single parent, earning £25,000, with one 3-year old daughter",
			make_hh(
				head_earn = 25_000/WEEKS_PER_YEAR,
				head_hours = 40,
				chu5 = 1 )),
		ExampleHH("family3","Unemployed Couple, 2 children", "Couple, neither currently working, with 2 children aged 7 and 9",
			make_hh(
				head_earn = 0.0,
				head_hours = 0,
				head_age = 30,
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 30,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 2 )),
		ExampleHH("family4","Working Family £12k, 2 children", "Couple, on low wages, with 2 children aged 6 and 10. She works, he says at home with the kids",
			make_hh(
				head_earn = 12_000/WEEKS_PER_YEAR,
				head_hours = 30,
				head_age = 35,
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 2 )),
		ExampleHH("family5","Working Family £35k, 2 children", "A couple with 3 year old twins. He works, she says at home with the kids",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 220.0,
				head_earn = 35_000/WEEKS_PER_YEAR,
				head_hours = 40,
				head_age = 35,
				spouse_earn = 0.0,
				spouse_hours = 0,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				chu5 = 2 )),
		ExampleHH("family6","Working Family £100k, 2 children", "A couple, with 2 children aged 6 and 2. Both work, each earning £50,000pa",
			make_hh(
				tenure  = Mortgaged_Or_Shared,
				hcost = 320.0,
				head_earn = 50_000/WEEKS_PER_YEAR,
				head_hours = 40,
				head_age = 35,
				spouse_earn = 50_000.0/WEEKS_PER_YEAR,
				spouse_hours = 40,
				spouse_age = 35,
				marrstat = Married_or_Civil_Partnership,
				ch5p = 1,
				chu5 = 1 )),
		ExampleHH("family8","Single female pensioner, aged 80", "A single pensioner, aged 80, with no private pension.",
			make_hh(
				hcost = 100,
				head_age = 80,
				marrstat = Single )),
		ExampleHH("family9","Pensioner couple, both aged 80", "A pensioner couple, both aged 80, with £100pw private pension.",
			make_hh(
				tenure  = Owned_outright,
				hcost = 0.0,
				head_private_pens = 100.0,
				head_age = 80,
				spouse_age = 80,
				marrstat = Married_or_Civil_Partnership ))
	]

function calc_examples( base :: TaxBenefitSystem, sys :: TaxBenefitSystem, settings :: Settings ) :: Vector
	v = []
	for ehh in EXAMPLE_HHS
		bres = do_one_calc( ehh.hh, base, settings )
		pres = do_one_calc( ehh.hh, sys, settings )
		push!( v, ( bres=bres, pres=pres ))
	end
	return v
end