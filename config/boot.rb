ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

if ENV.fetch("RAILS_ENV", "development") != "production"
	begin
		require "dotenv"
		root = File.expand_path("..", __dir__)
		rails_env = ENV.fetch("RAILS_ENV", "development")

		Dotenv.load(
			File.join(root, ".env"),
			File.join(root, ".env.local"),
			File.join(root, ".env.#{rails_env}"),
			File.join(root, ".env.#{rails_env}.local")
		)
	rescue LoadError
		# Dotenv is optional in this project.
	end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
