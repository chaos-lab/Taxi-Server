require File.expand_path("../spec_helper", __FILE__)

describe 'call taxi' do
  before(:all) do
    @passenger = Session.new
    @passenger.signup_passenger("passenger1", "liufy", "123456")
    @passenger.signin_passenger("passenger1", "123456")
    @passenger.update_passenger_location(118.3434, 32.5656)

    @driver = Session.new
    @driver.signup_driver("driver1", "cang", "123456", "AB-34534")
    @driver.signin_driver("driver1", "123456")
    @driver.update_driver_location(119.3434, 33.5656)

    @service_id = 0

  end

  it "should be able for passenger to get near taxi" do
    data = { :json_data => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.get '/taxi/near', data

    res.status.should == 0
    res.taxis.size.should > 0
    res.taxis[0].phone_number.should == @driver.phone_number
  end

  it "should be able for passenger to send taxi call" do
    res = @passenger.post '/service/create', :json_data => { location: { latitude: 118.2342, longitude: 32.43432 }, driver: "driver1",  key: 35432543 }.to_json
    res.status.should == 0
  end

  it "should be able for driver to receive taxi call" do
    res = @driver.get '/driver/refresh'
    res.status.should == 0
    res.messages?.should be_true
    res.messages[0].to_json.type.should == "call-taxi"
    res.messages[0].to_json.passenger.phone_number.should == "passenger1"
    @service_id = res.messages[0].to_json.id
  end

  it "should be able for driver to reply taxi call" do
    res = @driver.post '/service/reply', :json_data => { id: @service_id, accept: true }.to_json
    res.status.should == 0
  end

  it "should be able for passenger to receive taxi call reply" do
    res = @passenger.get '/passenger/refresh'
    res.status.should == 0
    res.messages?.should be_true
    res.messages[0].to_json.type.should == "call-taxi-reply"
    res.messages[0].to_json.accept.should == true
  end

  it "should be able for passenger to cancel taxi call" do
    res = @driver.post '/service/cancel', :json_data => { id: @service_id }.to_json
    res.status.should == 0
  end

  it "should be able for driver to receive taxi call cancel" do
    res = @driver.get '/driver/refresh'
    res.status.should == 0
    res.messages?.should be_true
    res.messages[0].to_json.type.should == "call-taxi-cancel"
    res.messages[0].to_json.id.should == @service_id
  end
end

