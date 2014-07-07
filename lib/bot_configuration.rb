require 'json'
require 'pp'

Repository = Struct.new(:github_repo, :project_or_workspace, :bots) do
end

Bot = Struct.new(:scheme, :run_analyzer, :run_test, :create_archive, :devices) do
end

class BotConfiguration
	attr_accessor :github_access_token
	attr_accessor :xcode_server
	attr_accessor :api_endpoint
	attr_accessor :web_endpoint
	attr_accessor :repos

	def initialize(fileName)
		@filename = File.expand_path(fileName)
		@data = JSON.parse(File.read(@filename))
		@github_access_token = @data["github_access_token"]
		@xcode_server = @data["xcode_server"]
		@api_endpoint = @data["api_endpoint"]
		@web_endpoint = @data["web_endpoint"]
		load_repos
	end

	def load_repos
		repos = @data["repos"]

		if repos.nil?
			puts "Could not load repos, for they do not exist."
			@repos = nil
		else
			@repos = repos.collect do |repo|
				bots = repo["bots"].collect do |bot|
					Bot.new(bot["scheme"], bot["run_analyzer"], bot["run_test"], bot["create_archive"], bot["unit_test_devices"])
				end
				Repository.new(repo["github_repo"], repo["project_or_workspace"], bots)
			end
		end
	end
end


if __FILE__ == $0
	c = BotConfiguration.new('~/xcode_bot_builder.json')
	pp c.repos
end
