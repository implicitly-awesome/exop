import Config

# do not write into log within tests
config :logger, backends: []
