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
  @configuration = BotConfiguration.new('~/Desktop/test.json')
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
    BotBuilder.instance.devices
  end

  def sync_github(args)
    client = Octokit::Client.new(:access_token => BotConfig.instance.github_access_token)
    client.login

    @configuration.repos.each do |repo|
      github = BotGithub.new(client, repo)
      github.sync
    end
  end

end