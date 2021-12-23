struct ParamsAndSettings 
	uuid         :: UUID
	cache_key    :: String
	sys          :: TaxBenefitSystem
	settings     :: Settings
end

struct AllOutput
	uuid         :: UUID
	cache_key    :: String 
	results     
	summary    
	gain_lose
	examples
end
