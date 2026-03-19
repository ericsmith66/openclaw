require 'sinatra'
require 'json'

set :port, 4567
set :bind, '0.0.0.0'  # Listen on LAN too

post '/event' do
  begin
    payload = JSON.parse(request.body.read)
    puts "Received event: #{payload.inspect}"
    status 200
    "Event received"
  rescue => e
    puts "Error: #{e.message}"
    status 400
    "Bad request"
  end
end

get '/' do
  "Ruby AI server is up on port 4567! (POST /event for HomeKit updates)"
end

get '/health' do
  "OK"
end
