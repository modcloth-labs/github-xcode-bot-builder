require 'json'
require 'pp'


Repository = Struct.new(:github_url, :github_repo, :xcode_scheme, :xcode_project_or_workspace) do
end


class BotConfiguration
	attr_accessor :repos

	def initialize(fileName)
		@filename = File.expand_path(fileName)
		@data = JSON.parse(File.read(@filename))
		load_repos
	end

	def load_repos
		repos = @data["repos"]

		if repos.nil?
			puts "Could not load repos, for they do not exist."
			@repos = nil
		else
			@repos = repos.collect do |repo|
				Repository.new(repo["github_url"], repo["github_repo"], repo["xcode_scheme"], repo["xcode_project_or_workspace"])
			end
		end
	end
end


if __FILE__ == $0
	c = BotConfiguration.new('~/Desktop/test.json')
	pp c.repos
end
