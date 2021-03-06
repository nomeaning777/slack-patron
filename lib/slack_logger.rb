require 'yaml'
require './lib/slack'
require './lib/db'

def parse_env_bool(env)
  return false if !env
  return false if  env == '' || env == '0' || env.downcase == 'false'
  return true
end

ENABLE_PRIVATE_CHANNEL = parse_env_bool(ENV['ENABLE_PRIVATE_CHANNEL'])
ENABLE_DIRECT_MESSAGE = parse_env_bool(ENV['ENABLE_DIRECT_MESSAGE'])
AUTO_JOIN = parse_env_bool(ENV['AUTO_JOIN'])

class SlackLogger
  def initialize
    @client = Slack::Web::Client.new
  end

  def update_users
    users = @client.users_list['members']
    replace_users(users)
  end

  def update_channels
    channels = @client.channels_list['channels']
    replace_channels(channels)
  end

  def update_groups
    groups = @client.groups_list['groups']
    replace_channels(groups)
  end

  def update_ims
    ims = @client.im_list['ims']
    replace_ims(ims)
  end

  # log history messages
  def fetch_history(target, channel)
    messages = @client.send(
      target,
      channel: channel,
      count: 1000,
    )['messages']

    unless messages.nil?
      messages.each do |m|
        m['channel'] = channel
        insert_message(m)
      end
    end
  end

  # realtime events
  def log_realtime
    realtime = Slack::RealTime::Client.new

    realtime.on :message do |m|
      puts m
      insert_message(m)
    end

    realtime.on :team_join do |e|
      puts "new user has joined"
      update_users
    end

    realtime.on :user_change do |e|
      puts "user data has changed"
      update_users
    end

    realtime.on :channel_created do |c|
      puts "channel has created"
      update_channels
      @client.channels_join(name: c[:channel][:name]) if AUTO_JOIN
    end

    realtime.on :channel_rename do |c|
      puts "channel has renamed"
      update_channels
    end

    realtime.on :channel_joined do |c|
      puts "it is joined on channel"
      update_channels
      fetch_history(:channels_history, c[:channel][:id])
    end

    if ENABLE_PRIVATE_CHANNEL
      realtime.on :group_joined do |c|
        puts "group has joined"
        update_groups
        fetch_history(:groups_history, c[:group][:id])
      end

      realtime.on :group_rename do |c|
        puts "group has renamed"
        update_groups
      end
    end

    if ENABLE_DIRECT_MESSAGE
      realtime.on :im_created do |c|
        puts "direct message has created"
        update_ims
        fetch_history(:im_history, c[:im][:id])
      end
    end

    # if connection closed, restart the realtime logger
    realtime.on :close do
      puts "websocket disconnected"
      log_realtime
    end

    realtime.start!
  end

  def log
    update_users
    update_channels
    update_groups if ENABLE_PRIVATE_CHANNEL
    update_ims if ENABLE_DIRECT_MESSAGE

    Channels.find.each do |c|
      puts "loading messages from #{c[:name]}"
      begin
        if c[:is_channel]
          fetch_history(:channels_history, c[:id])
        elsif c[:is_group] && ENABLE_PRIVATE_CHANNEL
          fetch_history(:groups_history, c[:id])
        end
      rescue Slack::Web::Api::Error => e
        STDERR.puts "failed to load messages from #{c[:name]}"
        STDERR.puts e.full_message
      end
      sleep(1)
    end

    if ENABLE_DIRECT_MESSAGE
      Ims.find.each do |i|
        fetch_history(:im_history, i[:id])
        sleep(1)
      end
    end
  end
end
