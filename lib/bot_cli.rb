require 'bot_builder'
require 'bot_github'
require 'bot_configuration'

# Patch net/http to set a reasonable open_timeout to prevent hanging
module Net
    class HTTP
        alias old_initialize initialize

        def initialize(*args)
            old_initialize(*args)
            @open_timeout = 60
        end
    end
end

class BotCli

def initialize()
  @configuration = BotConfiguration.new('~/xcode_bot_builder.json')
end

def delete(args)
  guid = args[0]
  if (guid == nil || guid.empty?)
    $stderr.puts "Missing guid of bot to delete"
    exit 1
  end
  BotBuilder.instance.delete_bot guid
end

def status(args)
  BotBuilder.instance.status
end

def devices(args)
  bot_builder = BotBuilder.new(@configuration.xcode_server, nil, nil)
  bot_builder.devices
end

def xcode_config(xcode, repo)
  config = xcode
  if repo.run_analyzer != nil
    config.run_analyzer = repo.run_analyzer
  end
  if repo.run_test != nil
    config.run_test = repo.run_test
  end
  if repo.create_archive != nil
    config.create_archive = repo.create_archive
  end
  config
end

def sync_github(args)
  Octokit.api_endpoint = @configuration.api_endpoint if @configuration.api_endpoint
  Octokit.web_endpoint = @configuration.web_endpoint if @configuration.web_endpoint
  client = Octokit::Client.new(:access_token => @configuration.github_access_token)
  client.login

  @configuration.repos.each do |repo|
    repo.bots.each_with_index do |bot, index|
      bot_builder = BotBuilder.new(@configuration.xcode_server, repo.project_or_workspace, bot)
      github = BotGithub.new(client, bot_builder, repo.github_repo, bot.scheme)
      update_github = index == repo.bots.length-1
      github.sync(update_github)
    end
  end
end

end
