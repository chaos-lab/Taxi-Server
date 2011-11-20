require 'rest-client'
require 'json'
require 'hashie'
require 'rspec'

SERVER_HOST = "http://127.0.0.1"

class Session
  attr_accessor :cookies, :phone_number, :nickname, :car_number, :latitude, :longitude

  def initialize
    @cookies = {}
  end

  def get(path, params = nil, &block)
    RestClient.get "#{SERVER_HOST}#{path}", {:params => params, :cookies => @cookies}  do |response, request, result|
      yield response if block_given?
      @cookies.merge!(response.cookies)
      Hashie::Mash.new(JSON.parse(response.body))
    end
  end

  def post(path, params = nil, &block)
    RestClient.post "#{SERVER_HOST}#{path}", params, {:cookies => @cookies}  do |response, request, result|
      yield response if block_given?
      @cookies.merge!(response.cookies)
      Hashie::Mash.new(JSON.parse(response.body))
    end
  end

  def signup_driver(_phone_number, _nickname, _password, _car_number)
    @phone_number = _phone_number
    @nickname = _nickname
    @car_number = _car_number
    data = { "json_data" => { phone_number: _phone_number, password: _password, nickname: _nickname, car_number: _car_number }.to_json }
    res = post '/driver/signup', data
    throw "sign up driver failed" unless res.status == 0
    return res
  end

  def signin_driver(_phone_number, _password)
    data = { "json_data" => { phone_number: _phone_number, password: _password }.to_json }
    res = post '/driver/signin', data
    throw "sign in driver failed" unless res.status == 0
    return res
  end

  def update_driver_location(_latitude, _longitude)
    @latitude = _latitude
    @longitude = _longitude
    data = { "json_data" => { latitude: _latitude, longitude: _longitude }.to_json }
    res = post '/driver/location/update', data
    throw "update driver location failed" unless res.status == 0
    return res
  end

  def signout_driver
    res = post '/driver/signout'
    throw "sign out driver failed" unless res.status == 0
    return res
  end

  def signup_passenger(_phone_number, _nickname, _password)
    @phone_number = _phone_number
    @nickname = _nickname
    data = { "json_data" => { phone_number: _phone_number, password: _password, nickname: _nickname }.to_json }
    res = post '/passenger/signup', data
    throw "sign up passenger failed" unless res.status == 0
    return res
  end

  def signin_passenger(_phone_number, _password)
    data = { "json_data" => { phone_number: _phone_number, password: _password }.to_json }
    res = post '/passenger/signin', data
    throw "sign in passenger failed" unless res.status == 0
    return res
  end

  def update_passenger_location(_latitude, _longitude)
    @latitude = _latitude
    @longitude = _longitude
    data = { "json_data" => { latitude: _latitude, longitude: _longitude }.to_json }
    res = post '/passenger/location/update', data
    throw "update passenger location failed" unless res.status == 0
    return res
  end

  def signout_passenger
    res = post '/passenger/signout'
    throw "sign out passenger failed" unless res.status == 0
    return res
  end
end

