"""
Wait to pull a job off the job queue and sent it
to the calculator. FIXME should also just generate text output.
"""
function calc_one()
	while true
		@debug "calc_one entered"
		params = take!( IN_QUEUE )
		@debug "params taken from IN_QUEUE; got params uuid=$(params.settings.uuid)"
		results = do_run_a( params.cache_key, params.sys, params.settings )
		@debug "model run OK; putting results into STASHED_RESULTS"		
		res_text = results_to_html( results.uuid, BASE_RESULTS, results )
		STASHED_RESULTS[ results.uuid ] = res_text
		CACHED_RESULTS[ results.cache_key ] = res_text
	end
end

#
# Set up job queues 
#
for i in 1:NUM_HANDLERS # start n tasks to process requests in parallel
    errormonitor(@async calc_one())
 end
 