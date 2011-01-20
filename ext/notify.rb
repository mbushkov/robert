#require 'action_mailer'

#defn notify.email do
#  var[:delivery_method] = lambda { :sendmail }
#
#  class ::Robert::NotifyEmailMailer < ActionMailer::Base
#    def notification(from, to, subject, body)
#      self.from from
#      self.recipients to
#      self.subject subject
#      self.body body
#    end
#  end
#
#  body { |*args|
#    send_email = lambda do |from = var[:from], to = var[:to], subject = var[:subject], body = var[:body]|
#      logd "sending email notification to #{to} from #{from} with subject '#{subject}'"
#      ::ActionMailer::Base.delivery_method = var[:delivery_method]
#      ::Robert::NotifyEmailMailer.deliver_notification(from, to, subject, body)
#    end
#
#    begin
#      call_next(*args)
#      with_rule_ctx(:success) { send_email.call unless var?[:silent] } rescue loge "can't send email success notification: #{$!}"
#    rescue => e
#      with_rule_ctx(:failure) { send_email.call unless var?[:silent] } rescue loge "can't send email failure notification: #{$!}"
#      raise
#    end
#  }
#end

notify_create_message = proc {
  <<__EOF
From: #{var[:email,:from]}
To: #{var[:email,:to]}
Subject: #{var[:email,:subject]}
Date: #{Time.now.rfc2822}
Message-Id: "#{Digest::MD5::hexdigest(Time.now.to_s + 'rob')}@#{var[:email,:domain]}"

#{var[:message]}
__EOF
}

defn notify.smtp do
  require 'net/smtp'
  require 'digest/md5'

  var[:smtp,:server,:host] = ->{ "localhost" }
  var[:smtp,:server,:port] = ->{ 25 }
  var[:smtp,:server,:helo] = var[:email,:domain] = ->{ "localhost.localdomain" }
  var[:smtp,:server,:user] = ->{ nil }
  var[:smtp,:server,:secret] = ->{ nil }
  var[:smtp,:server,:authtype] = ->{ nil }
  
  body { |*args|
    Net::SMTP.new(var[:smtp,:server,:host], var[:smtp,:server,:port]).
    start(var[:smtp,:server,:helo], var[:smtp,:server,:user],
          var[:smtp,:server,:secret], var[:smtp,:server,:authtype]) do |smtp|
      msg_str = instance_eval(&notify_create_message)
      smtp.send_message(msg_str, var[:from], var[:to])
    end
    call_next(*args) if has_next?
  }
end

defn notify.sendmail do
  require 'open4'
  
  var[:command] = ->{ "sendmail -t" }
  var[:email,:domain] = -> { "localhost.localdomain" }

  body { |*args|
    msg_str = instance_eval(&notify_create_message)
    status_code = Open4::popen4(var[:command], ) do |pid, stdin, stdout, stderr|
      stdin.write(msg_str)
      stdin.flush
      stdin.close

       out_thread = Thread.start {
        loop do
          $stdout.puts(stdout.readline)
        end rescue ""
      }
      err_thread = Thread.start {
        loop do
          $stderr.puts(stderr.readline)
        end rescue ""
      }

      out_thread.join
      err_thread.join
    end
    raise "sendmail deliver with command '#{var[:command]}' failed with code: #{status_code}" unless status_code == 0
    call_next(*args) if has_next?
  }
end

defn notify.campfire do
  body { |*args|
    speak = lambda do
      room = campfire(var[:site], var[:auth_token]).rooms.find { |r| r.name == var[:room] || r.id.to_s == var[:room] }
      raise "no room with name or id '#{var[:room]}" unless room
      room.message(var[:message])
    end

    begin
      call_next(*args) if has_next?
      with_rule_ctx(:success) { speak.call unless var?[:silent] } rescue loge "can't send campfire success notification: #{$!}"
    rescue => e
      with_rule_ctx(:failure) { speak.call unless var?[:silent] } rescue loge "can't send campfire success notification: #{$!}"
      raise
    end
  }
end

defn notify.jabber do
  require "xmpp4r/client"

  var[:use_ssl] = lambda { false }
  var[:host] = lambda { "talk.google.com" }
  var[:port] = lambda { 5222 }

  body { |*args|
    send_jabber_message = lambda do |message = var[:message]|
      jid = ::Jabber::JID.new("#{var[:jid]}/#{$$}")

      to = [var[:to]].flatten

      cl = Jabber::Client.new(jid)
      cl.use_ssl = var[:use_ssl]
      cl.connect(var[:host], var[:port])
      begin
        cl.auth(var[:password])
        to.each do |rcp|
          cl.send(::Jabber::Message.new(rcp, message).set_type(:normal).set_id("1"))
        end
      ensure
        cl.close
      end
    end    

    begin
      call_next(*args) if has_next?
      with_rule_ctx(:success) { send_jabber_message.call unless var?[:silent] } rescue loge "can't send jabber success notification: #{$!}"
    rescue => e
      with_rule_ctx(:failure) { send_jabber_message.call unless var?[:silent] } rescue loge "can't send jabber failure notification: #{$!}"
      raise
    end
  }
end
