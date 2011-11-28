# taxi call controller

User = require('../models/user')
Service = require('../models/service')

class TaxiCallController
  constructor: ->

  getNearTaxis: (req, res) ->
    taxis = []
  
    User.collection.find { role: 2, state: {$gte: 1}}, (err, docs)->
      for doc in docs
        taxis.push
          phone_number: doc.phone_number
          nickname: doc.nickname
          car_number: doc.car_number
          longitude: doc.location.longitude
          latitude: doc.location.latitude
  
    res.json { status: 0, taxis: taxis }
  
  create: (req, res) ->
    if req.json_data.driver
      req.json_data.state = 1
      req.json_data.passenger = req.current_user.phone_number

      Service.create req.json_data, (err, doc)->
        return res.json { status: 1 } if !doc
        message =
          type: "call-taxi",
          passenger:
            phone_number: req.current_user.phone_number
            nickname:req.current_user.nickname
          location: req.json_data.location
          id: doc._id
          timestamp: doc.created_at.valueOf()

        User.send(req.json_data.driver, message)
        res.json { status: 0, id: doc._id }
    else
      res.json { status: 1 }
  
  reply: (req, res) ->
    res.json { status: 1 }
  
  cancel: (req, res) ->
    res.json { status: 1 }

  complete: (req, res) ->
    res.json { status: 1 }

module.exports = TaxiCallController
