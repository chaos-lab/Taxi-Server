require File.expand_path("../spec_helper", __FILE__)

describe 'passenger' do
  before(:all) do
    @passenger = Session.new
  end

  it "should returns hello world" do
    res = @passenger.get "/"
    res.status.should == 0
    res.message.should == "hello, world!"
  end

  it "should be able to signup" do
    data = { "json_data" => { phone_number: "passenger1", password: "123456", nickname: "liufy" }.to_json }
    res = @passenger.post '/passenger/signup', data
    res.status.should == 0
  end

  it "should be disallowed to signup with incomplete info" do
    data = { "json_data" => { phone_number: "passenger1", password: "123456" }.to_json }
    res = @passenger.post '/passenger/signup', data
    res.status.should == 1
  end

  it "should be unable to update location before signin" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.post '/passenger/location/update', data
    res.status.should == 1
  end

  it "should be unable to signin with inexistent account" do
    data = { "json_data" => { phone_number: "xxxx", password: "abcd234" }.to_json }
    res = @passenger.post '/passenger/signin', data
    res.status.should == 1
  end

  it "should be unable to signin with incorrect credentials" do
    data = { "json_data" => { phone_number: "passenger1", password: "abcd234" }.to_json }
    res = @passenger.post '/passenger/signin', data
    res.status.should == 1
  end

  it "should be able to signin with correct credentials" do
    data = { "json_data" => { phone_number: "passenger1", password: "123456" }.to_json }
    res = @passenger.post '/passenger/signin', data
    res.status.should == 0
    res.self?.should be_true
  end

  it "should be disallowed to visit driver path" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.post '/driver/location/update', data
    res.status.should == 1
  end

  it "should be able to update location" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.post '/passenger/location/update', data
    res.status.should == 0
  end

  it "should be able to refresh" do
    res = @passenger.get '/passenger/refresh'
    res.status.should == 0
    res.messages?.should be_true
  end

  it "should be able to get near taxi" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.get '/taxi/near', data
    res.status.should == 0
    res.taxis?.should be_true
  end

  it "should be able to signout" do
    res = @passenger.post '/passenger/signout'
    res.status.should == 0
  end

  it "should be unable to update location after signout" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.post '/passenger/location/update', data
    res.status.should == 1
  end

end

