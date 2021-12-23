#
#
#
const BASE_UUID = UUID("985c312f-129b-4acd-9e40-cb629d184183")
const BASE_SETTINGS = initialise_settings()
const BASE_PARAMS = load_system()
const BASE_OUTPUT = do_run_a( "default", BASE_PARAMS, BASE_PARAMS, BASE_SETTINGS )
const BASE_TEXT_OUTPUT = results_to_html( BASE_UUID, BASE_OUTPUT, BASE_OUTPUT )


