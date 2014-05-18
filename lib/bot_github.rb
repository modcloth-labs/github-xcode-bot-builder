require 'octokit'
require 'singleton'
require 'bot_builder'
require 'ostruct'

class BotGithub
  attr_accessor :client, :bot_builder, :github_repo, :scheme

  def initialize(client, bot_builder, github_repo, scheme)
    self.client = client
    self.bot_builder = bot_builder
    self.github_repo = github_repo
    self.scheme = scheme
  end

  def bots_for_pull_request(bot_statuses, pr)
    bot_statuses.map do |bot_short_name_without_version, bot|
      if bot.pull_request == pr.number && bot.github_repo == pr.github_repo
        bot
      end
    end.compact
  end

  def github_url(github_repo)
    "git@github.com:#{github_repo}.git"
  end

  def sync(update_github)
    puts "\nStarting Github Xcode Bot Builder #{Time.now}\n-----------------------------------------------------------"
    # TODO: Need to clean up update_github, possibly by separating sync into the bot maintenance and github
    bot_statuses = self.bot_builder.status_of_all_bots
    bots_processed = []
    pull_requests.each do |pr|
      # Check if a bot exists for this PR
      bot = bot_statuses[pr.bot_short_name_without_version]
      bots_processed << pr.bot_short_name
      if (bot.nil?)
        # Create a new bot
        self.bot_builder.create_bot(pr.bot_short_name, pr.bot_long_name, pr.branch, github_url(github_repo))
        if update_github
          create_status_new_build(pr, bots_for_pull_request(bot_statuses, pr))
        end
      else
        bots = bots_for_pull_request(bot_statuses, pr)
        github_state_cur = latest_github_state(pr).state # :unknown :pending :success :error :failure
        github_state_new = convert_all_bot_status_to_github_state(bots)

        if (github_state_new == :pending && github_state_cur != github_state_new)
          # User triggered a new build by clicking Integrate on the Xcode server interface
          if update_github
            create_status(pr, github_state_new, bots)
          end
        elsif (github_state_cur == :unknown || user_requested_retest(pr, bot))
          # Unknown state occurs when there's a new commit so trigger a new build
          bot_builder.start_bot(bot.guid)
          if update_github
            create_status_new_build(pr, bots)
          end
        elsif (github_state_new != :unknown && github_state_cur != github_state_new)
          if update_github
            # Build has passed or failed so update status and comment on the issue
            create_comment_for_bot_status(pr, bots)
            create_status(pr, github_state_new, bots) #convert_bot_status_to_github_description(bot), bot.status_url)
          end
        else
          puts "PR #{pr.number} (#{github_state_cur}) is up to date for bot #{bot.short_name}"
        end
      end
    end

    # Delete bots that no longer have open pull requests
    bots_unprocessed = bot_statuses.keys - bots_processed
    bots_unprocessed.each do |bot_short_name|
      bot = bot_statuses[bot_short_name]
      # TODO: BotBuilder.instance.remove_outdated_bots(self.repo)
      self.bot_builder.delete_bot(bot.guid) unless !is_managed_bot(bot)
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

  def convert_all_bot_status_to_github_description(bots)
    description = bots.map do |bot| 
      case convert_bot_status_to_github_state(bot)
      when :error
        bot.scheme + " Error"
      when :failure
        bot.scheme + " Failed (" + bot.latest_run_sub_status.to_s + ")"
      end
    end.compact

    description.join(", ")
  end

  def convert_all_bot_status_to_url(bots)
    bots.each do |bot| 
      case convert_bot_status_to_github_state(bot)
      when :error
        return bot.status_url
      when :failure
        return bot.status_url
      end
    end
    return nil
  end

  def convert_all_bot_status_to_github_state(bots)
    error = false
    failure = false
    success = false
    pending = false
    bots.each do |bot|
      case convert_bot_status_to_github_state(bot)
      when :error
        error = true
      when :failure
        failure = true
      when :success
        success = true
      when :pending
        pending = true
      end
    end

    if pending
      return :pending
    elsif error
      return :error
    elsif failure
      return :failure
    elsif success
      return :success
    else
      return :error
    end

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

  def create_comment_for_bot_status(pr, bots)
    messages = {}
    messages[:error] = Array.new
    messages[:failure] = Array.new
    messages[:success] = Array.new

    bots.each do |bot|
      github_state = convert_bot_status_to_github_state(bot)
      if github_state != :unknown && github_state != :pending
        messages[github_state].push(bot.scheme + " Build " + convert_bot_status_to_github_state(bot).to_s.capitalize + ": " + convert_bot_status_to_github_description(bot))
        messages[github_state].push("#{bot.status_url}\n")
      end
    end
    message = messages.values.join("\n").strip
    unless message.empty?
      self.client.add_comment(self.github_repo, pr.number, message)
      puts "PR #{pr.number} added comment:\n#{message}"
    end
  end

  def create_status_new_build(pr, bots)
    create_status(pr, :pending, bots)
  end

  def create_status(pr, github_state, bots)
    description = convert_all_bot_status_to_github_description(bots)
    target_url = convert_all_bot_status_to_url(bots)
    options = {}
    if (!description.nil?)
      options['description'] = description
    end
    if (!target_url.nil?)
      options['target_url'] = target_url
    end
    self.client.create_status(self.github_repo, pr.sha, github_state.to_s, options)
    puts "PR #{pr.number} status updated to \"#{github_state}\" with description \"#{description}\""
  end

  def latest_github_state(pr)
    statuses = self.client.statuses(self.github_repo, pr.sha)
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
    responses = self.client.pull_requests(self.github_repo)
    responses.collect do |response|
      pull_request = OpenStruct.new
      pull_request.sha = response.head.sha
      pull_request.branch = response.head.ref
      pull_request.title = response.title
      pull_request.github_repo = github_repo
      pull_request.state = response.state
      pull_request.number = response.number
      pull_request.updated_at = response.updated_at
      pull_request.bot_short_name = bot_short_name(pull_request)
      pull_request.bot_short_name_without_version = bot_short_name_without_version(pull_request)
      pull_request.bot_long_name = bot_long_name(pull_request)
      pull_request
    end
  end

  def user_requested_retest(pr, bot)
    should_retest = false

    # Check for a user retest request comment
    comments = self.client.issue_comments(self.github_repo, pr.number)
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
    repo = self.github_repo
    if match = self.github_repo.match(/^([^ \/]+)\/([^ ]+)$/)
      repo = match.captures[1]
    end

    "#{repo} ##{pr.number} #{self.scheme} #{pr.branch} #{self.github_repo}"
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
    ('_' + self.github_repo.downcase + '_' + self.scheme.downcase + '_v').gsub(/[^[:alnum:]]/, '_')
  end

end
