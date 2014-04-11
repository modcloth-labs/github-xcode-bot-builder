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
    [:xcode_server, :github_url, :github_repo, :github_access_token, :xcode_devices, :xcode_scheme, :xcode_project_or_workspace, :xcode_run_analyzer, :xcode_run_test, :xcode_create_archive, :api_endpoint, :web_endpoint].each do |key|
      param key
    end
  end

  def optional_params
    [:api_endpoint, :web_endpoint]
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

  def xcode_run_analyzer
    param :xcode_run_analyzer
  end

  def xcode_run_test
    param :xcode_run_test
  end

  def xcode_create_archive
    param :xcode_create_archive
  end

  def api_endpoint
    param :api_endpoint
  end

  def web_endpoint
    param :web_endpoint
  end

  def param(key)
    value = @config[key.to_s]
    if (value.nil? && !optional_params.include?(key))
      $stderr.puts "Missing configuration key #{key} in #{@filename}"
      exit 1
    end
    value
  end
end
