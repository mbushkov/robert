ext :campfire do
  require 'httparty'
  require 'json'
  require 'ostruct'

  class Campfire
    include HTTParty

    headers    'Content-Type' => 'application/json'

    def initialize(site, auth_token)
      @opts = {:basic_auth => {:username => auth_token, :password => "X"}, :base_uri => "https://#{site}.campfirenow.com"}
    end

    def rooms
      Campfire.get('/rooms.json', @opts)["rooms"].map { |rh| Room.new(rh, @opts) }
    end

    def room(room_id)
      Room.new({:id => room_id}, @opts)
    end

    def user(id)
      Campfire.get("/users/#{id}.json", @opts)["user"]
    end
  end

  class Room < OpenStruct
    def initialize(values, opts)
      super(values)
      @opts = opts
    end

    def join
      post 'join'
    end

    def leave
      post 'leave'
    end

    def lock
      post 'lock'
    end

    def unlock
      post 'unlock'
    end

    def message(message)
      send_message message
    end

    def paste(paste)
      send_message paste, 'PasteMessage'
    end

    def play_sound(sound)
      send_message sound, 'SoundMessage'
    end

    def transcript
      get('transcript')['messages']
    end

    private

    def send_message(message, type = 'Textmessage')
      post('speak', {:body => {:message => {:body => message, :type => type}}.to_json}.merge(@opts))
    end

    def get(action, options = {})
      Campfire.get room_url_for(action), options.dup.merge(@opts)
    end

    def post(action, options = {})
      Campfire.post room_url_for(action), options.dup.merge(@opts)
    end

    def room_url_for(action)
      "/room/#{id}/#{action}.json"
    end
  end

  def campfire(site, token)
    Campfire.new(site, token)
  end
end
