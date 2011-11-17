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
  end

  it "passenger should be able to get near taxi" do
    data = { "json_data" => { latitude: 34.545, longitude: 118.324 }.to_json }
    res = @passenger.get '/passenger/taxi/near', data

    res.status.should == 0
    res.taxis.size.should > 0
    res.taxis[0].phone_number.should == @driver.phone_number
  end
end

