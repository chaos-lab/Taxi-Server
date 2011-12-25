# location controller

winston = require('winston')
Location = require('../models/location')

class LocationController
  constructor: ->

  ##
  # create location
  ##
  create: (req, res) ->
    unless req.json_data && req.json_data.latitude && req.json_data.longitude && req.json_data.name
      winston.warn("LocationController create - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    location =
      name: req.json_data.name
      position: [req.json_data.longitude, req.json_data.latitude]
    Location.collection.insert(location)

    res.json { status:0 }

module.exports = LocationController
