begin
  require 'rubygems'
  require 'xmpp4r'
  require 'drb'
  require 'daemons'
rescue LoadError
  puts $!.message
  exit
end

# Jabber::debug = true

class Notifier
  RECEIPIENTS ||= YAML.load_file('config/all.yml')["Receipients"].split

  def initialize(username, password, config={}, stop_thread=true)
    @mainthread = Thread.current
    login(username, password)
    send_initial_presence
    Thread.stop if stop_thread
  end

  def login(username, password)
    @jid    = Jabber::JID.new(username)
    @client = Jabber::Client.new(@jid)
    @client.connect
    @client.auth(password)
  end

  def logout
    @mainthread.wakeup
    @client.close
  end

  def send_initial_presence
    @client.send(Jabber::Presence.new.set_status(""))
  end

  def send_message(to, message)
    log("Sending message to #{to}")
    @client.send(Jabber::Message.new(to, message).set_type(:chat))
  end

  def notify(from, message)
    RECEIPIENTS.each do |r|
      send_message(r, "#{from} says: #{message}")
    end
  end

  def log(message)
    puts(message) if Jabber::debug
  end
end

NOTIFIER = YAML.load_file('config/all.yml')["Notifier"]
Daemons.run_proc('notifier', :dir_mode => :normal, :dir => 'pids') do
  DRb.start_service("druby://localhost:7777", Notifier.new(NOTIFIER["jid"], NOTIFIER["password"], {}, false))
  DRb.thread.join
end
