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

    @call_taxi_req = {
      :json_data => {
        to: @driver.phone_number, 
        from: @passenger.phone_number, 
        type: "call-taxi", 
        data: { 
          passenger: {
            phone_number: "1384323242",
            nickname: "liufy",
            longitude: 118.23432,
            latitude: 32.4343
          }
        }
      }.to_json
    }

    @call_taxi_reply = {
      :json_data => {
        to: @passenger.phone_number,
        from: @driver.phone_number,
        type: "call-taxi-reply",
        data: {
          accept: true
        }
      }.to_json
    }
  end

  it "should be able for passenger to get near taxi" do
    data = { :json_data => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.get '/passenger/taxi/near', data

    res.status.should == 0
    res.taxis.size.should > 0
    res.taxis[0].phone_number.should == @driver.phone_number
  end

  it "should be able for passenger to send taxi call" do
    res = @passenger.post '/passenger/message', @call_taxi_req
    res.status.should == 0
  end

  it "should be able for driver to receive taxi call" do
    res = @driver.get '/driver/refresh'
    res.status.should == 0
    res.messages?.should be_true
    res.messages[0].to_json.should == @call_taxi_req[:json_data]
  end

  it "should be able for driver to reply taxi call" do
    res = @driver.post '/driver/message', @call_taxi_reply
    res.status.should == 0
  end

  it "should be able for passenger to receive taxi call reply" do
    res = @passenger.get '/passenger/refresh'
    res.status.should == 0
    res.messages?.should be_true
    res.messages[0].to_json.should == @call_taxi_reply[:json_data]
  end

end

