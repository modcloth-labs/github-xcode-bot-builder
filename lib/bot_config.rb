require 'singleton'
require 'parseconfig'

class BotConfig
  include Singleton

  def initialize
    @filename = File.expand_path('~/.bot-sync-github.cfg')
    if (!File.exists? @filename)
      $stderr.puts "Missing configuration file #{@filename}"
      exit 1
    end

    @config = ParseConfig.new(@filename)

    # Make sure every param is configured properly since param will throw an error for a missing key
    [:xcode_server, :github_url, :github_repo, :github_access_token, :xcode_devices, :xcode_scheme, :xcode_project_or_workspace].each do |key|
      param key
    end
  end

  def xcode_server_hostname
    param :xcode_server
  end

  def github_access_token
    param :github_access_token
  end

  def scm_path
    param :github_url
  end

  def github_repo
    param :github_repo
  end

  def xcode_devices
    param(:xcode_devices).split('|')
  end

  def xcode_scheme
    param :xcode_scheme
  end

  def xcode_project_or_workspace
    param :xcode_project_or_workspace
  end

  def param(key)
    value = @config[key.to_s]
    if (value.nil?)
      $stderr.puts "Missing configuration key #{key} in #{@filename}"
      exit 1
    end
    value
  end
end