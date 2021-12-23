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

#
#
PROGRESS = Dict{UUID,Any}()

# FIXME we can simplify this by directly creating the outputs
# as a string and just saving that in STASHED_RESULTS
STASHED_RESULTS = Dict{UUID,Any}()

# Save results by query string & just return that
# TODO complete this.
CACHED_RESULTS = Dict{String,Any}()
