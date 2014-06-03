require 'net/http'
require 'uri'
require 'cgi/cookie'
require 'SecureRandom'
require 'json'
require 'pp'
require 'singleton'
require 'ostruct'

class BotBuilder
  attr_accessor :server
  attr_accessor :project_path
  attr_accessor :bot

  def initialize(server, project_path, bot)
    self.server = server
    self.project_path = project_path
    self.bot = bot
  end

  def delete_bot(guid)
    success = false
    service_requests = [ service_request('deleteBotWithGUID:', [guid]) ]
    delete_info = batch_service_request(service_requests)
    if (delete_info['responses'][0]['responseStatus'] == 'succeeded')
      puts "BOT Deleted #{guid}"
      success = true
    else
      puts "Error deleting BOT #{guid}"
    end
  end

  def github_ssh_url(github_repo)
    "git@github.com:#{github_repo}.git"
  end

  def github_https_url(github_repo)
    "https://github.com/#{github_repo}.git"
  end

  def create_bot(short_name, long_name, branch, repo)
    device_guids = find_guids_for_devices(bot.devices)
    if (device_guids.count != bot.devices.count)
      puts "Some of the following devices could not be found on the server: #{devices}"
      exit 1
    end

    scm_guid = find_guid_for_scm_url(github_ssh_url(repo))
    if (scm_guid.nil? || scm_guid.empty?)
      scm_guid = find_guid_for_scm_url(github_https_url(repo))
      if (scm_guid.nil? || scm_guid.empty?)
        puts "Could not find repository on the server #{scm_url}"
        exit 1
      end
    end

    # Create the bot
    buildSchemeKey = (self.project_path =~ /xcworkspace/) ? :buildWorkspacePath : :buildProjectPath

    service_requests = [
      service_request('createBotWithProperties:', [
        {
          shortName: short_name,
          longName: long_name,
          extendedAttributes: {
            cmInfo: {
            "/" => {
                scmBranch: branch,
              }
            },
            scmInfoGUIDMap: {
              "/" => scm_guid
            },
            buildSchemeKey => self.project_path,
            buildSchemeName: self.bot.scheme,
            pollForSCMChanges: false,
            buildOnTrigger: false,
            buildFromClean: true,
            integratePerformsAnalyze: self.bot.run_analyzer,
            integratePerformsTest: self.bot.run_test,
            integratePerformsArchive: self.bot.create_archive,
            deviceSpecification: "specificDevices",
            deviceInfo: device_guids
          },
          notifyCommitterOnSuccess: false,
          notifyCommitterOnFailure: false,
          type: "com.apple.entity.Bot"
        }
      ])
    ]
    bot_info = batch_service_request(service_requests)
    bot_guid = bot_info['responses'][0]['response']['guid']
    puts "BOT Created #{bot_guid} #{short_name}"

    # Start the bot
    start_bot bot_guid

    bot_guid
  end

  def cancel_bot(bot_guid)
    status_of_bot(bot_guid).each do |id, integration|
      if integration.status == :running or integration.status == :ready
        cancel_bot_integration(integration.guid)
        puts "BOT Integration ##{id} Canceled"
        return
      end
    end
  end

  def cancel_bot_integration(integration_guid)
    service_requests = [ service_request('cancelBotRunWithGUID:', [integration_guid]) ]
    bot_start_info = batch_service_request(service_requests)
  end

  def start_bot(bot_guid)
    cancel_bot(bot_guid)
    if integration_queued(bot_guid)
      puts "BOT Already Queued #{bot_guid}"
    else
      service_requests = [ service_request('startBotRunForBotGUID:', [bot_guid]) ]
      bot_start_info = batch_service_request(service_requests)
      puts "BOT Started #{bot_guid}"
    end
  end

  def integration_queued(bot_guid)
    status_of_bot(bot_guid).each do |id, integration|
      if integration.status == :ready
        return true
      end
    end
    return false
  end

  def status_of_bot(bot_guid)
    service_requests = [ service_request('query:', [
      {
        query: {
          and: [
            {
              or: [
                {
                  match: 'com.apple.entity.BotRun',
                  field: 'type',
                  exact: true
                }
              ]
            },
            {
              match: bot_guid,
              field: 'ownerGUID',
              exact: true
            }
          ]
        },
        fields: ['tinyID','longName','shortName','type','createTime','startTime','endTime','status','subStatus','integration'],
        subFields: {},
        sortFields: ['createTime'],
        range: [0, 26],
        onlyDeleted: false
      }
    ], 'SearchService') ]
    status_info = batch_service_request(service_requests)
    results =  status_info['responses'][0]['response']['results']
    integrations = {}
    results.each do |result|
      integration = OpenStruct.new result['entity']
      integration.status = (integration.status.nil? || integration.status.empty?) ? :unknown : integration.status.to_sym
      integrations[integration.integration] = integration
    end
    integrations
  end

  def status_of_all_bots
    # After immediately creating: latest_run_status "" run_sub_status ""
    # While running: latest_run_status "running" run_sub_status ""
    # After completion: latest_run_status "completed" run_sub_status "build-failed|build-errors|test-failures|warnings|analysis-issues|succeeded"
    service_requests = [ service_request('query:', [
      {
        fields: ['guid','tinyID','latestRunStatus','latestRunSubStatus','longName'],
        entityTypes: ["com.apple.entity.Bot"]
      }
    ], 'SearchService') ]
    status_info = batch_service_request(service_requests)
    results =  status_info['responses'][0]['response']['results']
    statuses = {}
    results.each do |result|
      bot = OpenStruct.new result['entity']
      bot.status_url = "http://#{@server}/xcode/bots/#{bot.tinyID}"
      bot.latest_run_status = (bot.latestRunStatus.nil? || bot.latestRunStatus.empty?) ? :unknown : bot.latestRunStatus.to_sym
      bot.latest_run_sub_status = (bot.latestRunSubStatus.nil? || bot.latestRunSubStatus.empty?) ? :unknown : bot.latestRunSubStatus.to_sym
      bot.short_name = bot.tinyID
      bot.short_name_without_version = bot.short_name.sub(/_v\d*$/, '_v')
      bot.pull_request = nil
      bot.github_repo = nil
      bot.scheme = nil
      if match = bot.longName.match(/^([^ ]+) #([0-9]+) ([^ ]+) ([^ ]+) ([^ \/]+\/[^ ]+)$/)
        matches = match.captures
        bot.pull_request = matches[1].to_i
        bot.github_repo = matches[4]
        bot.scheme = matches[2]
      end
      statuses[bot.short_name_without_version] = bot
    end
    statuses
  end

  def status
    status_of_all_bots.values.each do |bot|
      puts "#{bot.status_url} #{bot.latest_run_status} #{bot.latest_run_sub_status}"
    end
  end

  def devices
    device_info = get_device_info
    device_info.each do |device|
      puts device_string_for_device(device)
    end
  end

  private

  def find_guid_for_scm_url(scm_url)
    scm_info = get_scm_info
    scm_guid = nil
    scm_info.each do |scm|
      if (scm['scmRepoPath'] == scm_url)
        scm_guid = scm['scmGUID']
      end
    end
    scm_guid
  end

  def find_guids_for_devices(devices)
    device_info = get_device_info
    device_guids = {}
    device_info.each do |device|
      device_string = device_string_for_device(device)
      if (devices.include? device_string)
        device_guids.store(device_string, device['guid'])
      end
    end
    device_guids.values
  end

  def device_string_for_device(device)
    "#{device['adcDevicePlatform']} #{device['adcDeviceName']} #{device['adcDeviceSoftwareVersion']}"
  end

  def get_device_info
    # Put to get device and Device Info
    service_requests = [
      service_request('allDevices', [])
    ]
    device_info = batch_service_request(service_requests)['responses'][0]['response']
    device_info
  end

  def get_scm_info
    # Put to get device and Device Info
    service_requests = [
      service_request('findAllSCMInfos', [])
    ]
    scm_info = batch_service_request(service_requests)['responses'][0]['response']
    scm_info
  end

  def get_session_guid
    # Get the guid
    if (@session_guid == nil)
      response = Net::HTTP.get_response(URI.parse("http://#{@server}/xcode"))
      cookies = CGI::Cookie::parse(response['set-cookie'])
      @session_guid = cookies['cc.collabd_session_guid']
    end
    @session_guid
  end

  def batch_service_request(service_requests)
    payload = {
      type: 'com.apple.BatchServiceRequest' ,
      requests: service_requests
    }
    http = Net::HTTP.new(@server)
    request = Net::HTTP::Put.new('/collabdproxy')
    request['Content-Type'] = 'application/json; charset=UTF-8'
    request['Cookie'] = "cc.collabd_session_guid=#{@session_guid}"
    request.body = payload.to_json
    response = http.request(request)
    json = JSON.parse(response.body)
    # response_status = json['responses'][0]['responseStatus']
    # puts "Result status #{response_status}"
    json
  end

  def service_request(name, arguments, service = 'XCBotService')
    get_session_guid
    {
      type: 'com.apple.ServiceRequest',
      arguments: arguments,
      sessionGUID: @session_guid,
      serviceName: service,
      methodName: name,
      expandReferencedObjects: false
    }
  end

end
