require 'octokit'
require 'singleton'
require 'bot_config'
require 'bot_builder'
require 'ostruct'

class BotGithub
  include Singleton

  def initialize
    Octokit.api_endpoint = BotConfig.instance.api_endpoint if BotConfig.instance.api_endpoint
    Octokit.web_endpoint = BotConfig.instance.web_endpoint if BotConfig.instance.web_endpoint
    @client = Octokit::Client.new :access_token => BotConfig.instance.github_access_token
    @client.login
  end

  def sync
    puts "\nStarting Github Xcode Bot Builder #{Time.now}\n-----------------------------------------------------------"
    # Check to see if we're already running and skip this run if so
    running_instances = `ps aux | grep [b]ot-sync-github | grep -v bin/sh`.split("\n")
    if (running_instances.count > 1)
      $stderr.puts "Skipping run since bot-sync-github is already running"
      PP.pp(running_instances, STDERR)
      exit 1
    end

    bot_statuses = BotBuilder.instance.status_of_all_bots
    bots_processed = []
    pull_requests.each do |pr|
      # Check if a bot exists for this PR
      bot = bot_statuses[pr.bot_short_name_without_version]
      bots_processed << pr.bot_short_name
      if (bot.nil?)
        # Create a new bot
        BotBuilder.instance.create_bot(pr.bot_short_name, pr.bot_long_name, pr.branch,
                                       BotConfig.instance.scm_path,
                                       BotConfig.instance.xcode_project_or_workspace,
                                       BotConfig.instance.xcode_scheme,
                                       BotConfig.instance.xcode_devices)
        create_status_new_build(pr)
      else
        github_state_cur = latest_github_state(pr).state # :unknown :pending :success :error :failure
        github_state_new = convert_bot_status_to_github_state(bot)

        if (github_state_new == :pending && github_state_cur != github_state_new)
          # User triggered a new build by clicking Integrate on the Xcode server interface
          create_status(pr, github_state_new, convert_bot_status_to_github_description(bot), bot.status_url)
        elsif (github_state_cur == :unknown || user_requested_retest(pr, bot))
          # Unknown state occurs when there's a new commit so trigger a new build
          BotBuilder.instance.start_bot(bot.guid)
          create_status_new_build(pr)
        elsif (github_state_new != :unknown && github_state_cur != github_state_new)
          # Build has passed or failed so update status and comment on the issue
          create_comment_for_bot_status(pr, bot)
          create_status(pr, github_state_new, convert_bot_status_to_github_description(bot), bot.status_url)
        else
          puts "PR #{pr.number} (#{github_state_cur}) is up to date for bot #{bot.short_name}"
        end
      end
    end

    # Delete bots that no longer have open pull requests
    bots_unprocessed = bot_statuses.keys - bots_processed
    bots_unprocessed.each do |bot_short_name|
      bot = bot_statuses[bot_short_name]
      BotBuilder.instance.delete_bot(bot.guid) unless !is_managed_bot(bot)
    end

    puts "-----------------------------------------------------------\nFinished Github Xcode Bot Builder #{Time.now}\n"
  end

  private

  def convert_bot_status_to_github_description(bot)
    bot_run_status = bot.latest_run_status # :unknown :running :completed
    bot_run_sub_status = bot.latest_run_sub_status # :unknown :build-failed :build-errors :test-failures :warnings :analysis-issues :succeeded
    github_description = bot_run_status == :running ? "Build Triggered." : ""
    if (bot_run_status == :completed || bot_run_status == :failed)
      github_description = bot_run_sub_status.to_s.split('-').map(&:capitalize).join(' ') + "."
    end
    github_description
  end

  def convert_bot_status_to_github_state(bot)
    bot_run_status = bot.latest_run_status # :unknown :running :completed
    bot_run_sub_status = bot.latest_run_sub_status # :unknown :build-failed :build-errors :test-failures :warnings :analysis-issues :succeeded
    github_state = bot_run_status == :running ? :pending : :unknown
    if (bot_run_status == :completed || bot_run_status == :failed)
      github_state = case bot_run_sub_status
                       when :"test-failures", :"warnings", :"analysis-issues"
                         :failure
                       when :"succeeded"
                         :success
                       else
                         :error
                     end
    end
    github_state
  end

  def create_comment_for_bot_status(pr, bot)
    message = "Build " + convert_bot_status_to_github_state(bot).to_s.capitalize + ": " + convert_bot_status_to_github_description(bot)
    message += "\n#{bot.status_url}"
    @client.add_comment(BotConfig.instance.github_repo, pr.number, message)
    puts "PR #{pr.number} added comment \"#{message}\""
  end

  def create_status_new_build(pr)
    create_status(pr, :pending, "Build Triggered.")
  end

  def create_status(pr, github_state, description = nil, target_url = nil)
    options = {}
    if (!description.nil?)
      options['description'] = description
    end
    if (!target_url.nil?)
      options['target_url'] = target_url
    end
    @client.create_status(BotConfig.instance.github_repo, pr.sha, github_state.to_s, options)
    puts "PR #{pr.number} status updated to \"#{github_state}\" with description \"#{description}\""
  end

  def latest_github_state(pr)
    statuses = @client.statuses(BotConfig.instance.github_repo, pr.sha)
    status = OpenStruct.new
    if (statuses.count == 0)
      status.state = :unknown
      status.updated_at = Time.now
    else
      status.state = statuses[0].state.to_sym
      status.updated_at = statuses[0].updated_at
    end
    status
  end

  def pull_requests
    github_repo = BotConfig.instance.github_repo
    responses = @client.pull_requests(github_repo)
    prs = []
    responses.each do |response|
      pr = OpenStruct.new
      pr.sha = response.head.sha
      pr.branch = response.head.ref
      pr.title = response.title
      pr.state = response.state
      pr.number = response.number
      pr.updated_at = response.updated_at
      pr.bot_short_name = bot_short_name(pr)
      pr.bot_short_name_without_version = bot_short_name_without_version(pr)
      pr.bot_long_name = bot_long_name(pr)
      prs << pr
    end
    prs
  end

  def user_requested_retest(pr, bot)
    should_retest = false
    github_repo = BotConfig.instance.github_repo

    # Check for a user retest request comment
    comments = @client.issue_comments(github_repo, pr.number)
    latest_retest_time = Time.at(0)
    found_retest_comment = false
    comments.each do |comment|
      if (comment.body =~ /retest/i)
        latest_retest_time = comment.updated_at
        found_retest_comment = true
      end
    end

    return should_retest unless found_retest_comment

    # Get the latest status time
    latest_status_time = latest_github_state(pr)
    if (latest_status_time.nil? || latest_status_time.updated_at.nil?)
      latest_status_time = Time.at(0)
    end

    if (latest_retest_time > latest_status_time.updated_at)
      should_retest = true
      puts "PR #{pr.number} user requested a retest"
    end

    should_retest
  end

  def bot_long_name(pr)
    github_repo = BotConfig.instance.github_repo
    "PR #{pr.number} #{pr.title} #{github_repo}"
  end

  def bot_short_name(pr)
    short_name = "#{pr.number}-#{pr.branch}".gsub(/[^[:alnum:]]/, '_') + bot_short_name_suffix
    short_name
  end

# For duplicate bot names xcode server appends a version
# bot_short_name_v, bot_short_name_v1, bot_short_name_v2. This method converts bot_short_name_v2 to bot_short_name_v
  def bot_short_name_without_version(pr)
    bot_short_name(pr).sub(/_v\d*$/, '_v')
  end

  def is_managed_bot(bot)
    # Check the suffix of the bot to see if it matches the bot_short_name_suffix
    bot.short_name =~ /#{bot_short_name_suffix}\d*$/
  end

  def bot_short_name_suffix
    github_repo = BotConfig.instance.github_repo.downcase
    ('_' + github_repo + '_v').gsub(/[^[:alnum:]]/, '_')
  end

end
