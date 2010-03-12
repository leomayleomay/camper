begin
  require 'rubygems'
  require 'drb'
  require 'httparty'
  require 'json'
  # sudo gem install twitter-stream -s http://gemcutter.org
  # http://github.com/voloko/twitter-stream
  require 'twitter/json_stream'
rescue LoadError
  puts $!.message
  exit
end

module Campfire
  extend self

  campfire_conf = YAML.load_file("config/all.yml")["Campfire"]
  DOMAIN        = campfire_conf["domain"]
  API_TOKEN     = campfire_conf["api_token"]

  include HTTParty
  base_uri    DOMAIN
  basic_auth  API_TOKEN, 'x'
  headers     'Content-Type' => 'application/json'

  def stream
    EventMachine::run do
      rooms.each do |room|
        stream = Twitter::JSONStream.connect(options_for_room(room["id"]))

        stream.each_item do |item|
          message = ::JSON.parse(item)
          from = "(#{room['name']}) #{user(message['user_id'])}" if message["user_id"]
          remote_notifier.notify(from, message["body"]) if message["body"]
        end

        stream.on_error do |message|
          puts "ERROR:#{message.inspect}"
        end

        stream.on_max_reconnects do |timeout, retries|
          puts "Tried #{retries} times to connect."
          exit
        end
      end
    end
  end

  private
  def rooms
    @rooms ||= get('/rooms.json')["rooms"]
  end

  def user(id)
    @users ||= {}
    return @users[id] if @users.has_key?(id)
    @users[id] = get("/users/#{id}.json")["user"]["name"]
  end

  def options_for_room(room_id)
    {
      :path => "/room/#{room_id}/live.json",
      :host => "streaming.campfirenow.com",
      :auth => "#{API_TOKEN}:x"
    }
  end

  def remote_notifier
    return @remote_notifier if @remote_notifier
    DRb.start_service
    @remote_notifier = DRbObject.new_with_uri "druby://localhost:7777"
  end
end
