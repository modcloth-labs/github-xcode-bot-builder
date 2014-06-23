Github Xcode Bot Builder
========================

A command line tool that creates/manages/deletes Xcode 5 server bots for each Github pull request. 
When a pull request is opened a corresponding Xcode bot is created. 
When a new commit is pushed the bot is re-run. 
When the build finishes the github pull request status is updated with a comment if there's an error. 
Users can request that a pull request be retested by adding a comment that includes the word "retest" (case insensitive). 
When a pull request is closed the corresponding bot is deleted.

Setup
=====
Make sure your Xcode server is correctly setup to allow ANYONE to create a build (without a username or password, see suggested features below). Then make sure you can manually create and execute a build and run it.

Install XCode Command Line tools
```
xcode-select --install
```

Clone the github-xcode-bot-builder repository and run bundle install.
```
ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future bundle install
```

Go to your [Github Account Settings](https://github.com/settings/applications) and create a personal access token which
you will use as your *github_access_token* so that the **bot-sync-github** script can access your github repo

Create a ~/xcode_bot_builder.json

The example below shows two projects, one project running a single scheme, the other running two different schemes.  The pull request will not be marked successful, unless both schemes pass.

```
{
  "github_access_token": "0123456789012345678901234567890123456789",
  "xcode_server": "192.168.1.1",
  "repos": [
    {
      "github_repo": "org/project1",
      "project_or_workspace": "project1.xcodeproj",
      "bots": [
        {
          "scheme": "Project1",
          "run_analyzer": true,
          "run_test": true,
          "create_archive": true,
          "unit_test_devices": [
            "iphonesimulator iPhone Retina (4-inch) 7.1",
            "iphonesimulator iPhone Retina (4-inch 64-bit) 7.1"
          ]
        }
      ]
    },
    {
      "github_repo": "org/project2",
      "project_or_workspace": "project2.xcodeproj",
      "bots": [
        {
          "scheme": "Project2",
          "run_analyzer": true,
          "run_test": false,
          "create_archive": false,
          "unit_test_devices": [
            "iphonesimulator iPhone Retina (4-inch) 7.1"
          ]
        },
        {
          "scheme": "Project2Tests",
          "run_analyzer": false,
          "run_test": true,
          "create_archive": false,
          "unit_test_devices": [
            "iphonesimulator iPhone Retina (4-inch) 7.1",
            "iphonesimulator iPhone Retina (4-inch 64-bit) 7.1"
          ]
        }
      ]
    }
  ]
}
```

The api_endpoint and web_endpoint urls can be configured if you use a github enterprise setup, otherwise they can be omitted.

Manually run **bot-sync-github** from the command line to make sure it works.  If you have any open pull requests, a bot should have been created, and the integration started.

Schedule **bot-sync-github** to run in cron every couple of minutes. Apple's strongly encourages the use of launchd.
A simple way to do this is to put the following in /Library/LaunchDaemons/com.example.github-xcode-bot-builder.plist
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.github-xcode-bot-builder</string>

  <key>UserName</key>
  <string>xcodebots</string>
  
  <key>ProgramArguments</key>
  <array>
    <string>/Users/xcodebots/github-xcode-bot-builder/bin/bot-sync-github</string>
  </array>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/tmp/github-xcode-bot-builder.log</string>
</dict>
</plist>
```

Then to start:
```
sudo launchctl load /Library/LaunchDaemons/com.example.github-xcode-bot-builder.plist
```

If you want to stop:
```
sudo launchctl unload /Library/LaunchDaemons/com.example.github-xcode-bot-builder.plist
```

You can also use cron.  For example, if you're using RVM:

```
*/2 * * * * $HOME/.rvm/bin/ruby-2.0.0-p247 $HOME/.rvm/gems/ruby-2.0.0-p247/bin/bot-sync-github >> /tmp/bot-sync-github.log 2>&1
```

Troubleshooting
===============
Send us a pull request with your troubleshooting tips here!

Contributing
============

* Github Xcode Bot Builder uses [Jeweler](https://github.com/technicalpickles/jeweler) for managing the Gem, versioning,
  generating the Gemspec, etc. so do not manually edit the gemspec since it is auto generated from the Rakefile.
* Check out the latest **master** to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Don't forget to add yourself to the contributors section below

Suggested features to contribute
================================
* Support for configuring username and password to use with your Xcode server
* Add specs that use VCR to help us add test coverage
* Add better error handling
* Update this README.md to make it easier for new users to get started and troubleshoot

Contributors
============
 - [ModCloth](http://www.modcloth.com/)
 - [Geoffery Nix](http://github.com/geoffnix)
 - [Two Bit Labs](http://twobitlabs.com/)
 - [Todd Huss](http://github.com/thuss)
 - [Dave Kasper](http://github.com/dkasper)
 - [Banno](http://www.banno.com)

Copyright
=========

Copyright (c) 2013 ModCloth. See LICENSE for further details.


