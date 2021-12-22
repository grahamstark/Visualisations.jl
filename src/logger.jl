# configure logger; see: https://docs.julialang.org/en/v1/stdlib/Logging/index.html
# and: https://github.com/oxinabox/LoggingExtras.jl
logger = FileLogger("/var/tmp/stb_log.txt")
global_logger(logger)
LogLevel( Logging.Debug )
