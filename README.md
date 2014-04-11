Github Xcode Bot Builder
========================

A command line tool that creates/manages/deletes Xcode 5 server bots for each Github pull request. When a pull request is opened
a corresponding Xcode bot is created. When a new commit is pushed the bot is re-run. When the build finishes the github
pull request status is updated with a comment if there's an error. Users can request that a pull request be retested by
adding a comment that includes the word "retest" (case insensitive). When a pull request is closed the corresponding
bot is deleted.

Setup
=====
Make sure your Xcode server is correctly setup to allow ANYONE to create a build (without a username or password, see suggested features below).
Then make sure you can manually create and execute a build and run it.

Create a ~/.bot-sync-github.cfg

Go to your [Github Account Settings](https://github.com/settings/applications) and create a personal access token which
you will use as your *github_access_token* so that the **bot-sync-github** script can access your github repo

```
github_access_token = 57244a72a7ca33931a40eb4ec21621505ab9f6b3
github_url = https://github.com/someuser/Some-Repo.git
github_repo = someuser/Some-Repo
xcode_server = 192.168.10.123
xcode_devices = iphonesimulator iPhone Retina (4-inch) 7.0|iphonesimulator iPhone Retina (4-inch) 6.1
xcode_scheme = Some-Scheme-Name-app
xcode_project_or_workspace = SomeProject.xcworkspace # or SomeProject.xcproject
xcode_run_analyzer = 1 # or 0 to not run the analyzer
xcode_run_test = 1 # or 0 to not run the tests
xcode_create_archive = 1 # or 0 to not create an archive
api_endpoint = https://enterprise.domain.com/api/v3
web_endpoint = https://enterprise.domain.com
```

Note that *xcode_devices* need to be pipe delimited. To get the list of available devices run the bot-devices command.
The *xcode_server* can either be an ip address or a hostname.
The api_endpoint and web_endpoint urls can be configured if you use a github enterprise setup, otherwise they can be omitted.

Manually run **bot-sync-github** from the command line to make sure it works

Schedule **bot-sync-github** to run in cron every couple of minutes. For example if you're using RVM:

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
* Add support for multiple repositories
* Add better error handling
* Update this README.md to make it easier for new users to get started and troubleshoot

Contributors
============
 - [ModCloth](http://www.modcloth.com/)
 - [Geoffery Nix](http://github.com/geoffnix)
 - [Two Bit Labs](http://twobitlabs.com/)
 - [Todd Huss](http://github.com/thuss)
 - [Dave Kasper](http://github.com/dkasper)

Copyright
=========

Copyright (c) 2013 ModCloth. See LICENSE for further details.


