class TaxiCallController
  constructor: ->

  getNearTaxis: (req, res) ->
    taxis = []
  
    _.each drivers, (driver, phone) ->
      if driver.status > 0 && driver.location
        taxis.push
          phone_number: driver.phone_number
          nickname: driver.nickname
          car_number: driver.car_number
          longitude: driver.location.longitude
          latitude: driver.location.latitude
  
    res.json { status: 0, taxis: taxis }
  
  create: (req, res) ->
  
  reply: (req, res) ->
  
  cancel: (req, res) ->
  
  complete: (req, res) ->

module.exports = TaxiCallController
