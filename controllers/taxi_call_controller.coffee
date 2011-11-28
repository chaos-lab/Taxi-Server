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
  
  reply: (req, res) ->
  
  cancel: (req, res) ->
  
  complete: (req, res) ->

module.exports = TaxiCallController
