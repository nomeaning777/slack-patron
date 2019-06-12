require 'yaml'
require 'slack'

Slack.configure do |c|
  c.token = ENV['SLACK_TOKEN']
end
