# taxi call controller

User = require('../models/user')
Service = require('../models/service')

class TaxiCallController
  constructor: ->

  getNearTaxis: (req, res) ->
    taxis = []
  
    User.collection.find { role: 2, state:{$gte: 1} }, {}, (err, docs)->
      for doc in docs
        taxis.push
          phone_number: doc.phone_number
          nickname: doc.nickname
          car_number: doc.car_number
          longitude: doc.location.longitude
          latitude: doc.location.latitude
  
      res.json { status: 0, taxis: taxis }
  
  create: (req, res) ->
    return res.json { status: 1 } unless req.json_data.driver

    req.json_data.state = 1
    req.json_data.passenger = req.current_user.phone_number

    Service.create req.json_data, (err, doc)->
      return res.json { status: 1 } unless doc

      message =
        type: "call-taxi"
        passenger:
          phone_number: req.current_user.phone_number
          nickname:req.current_user.nickname
        location: req.json_data.location
        id: doc._id
        timestamp: new Date().valueOf()

      User.send(req.json_data.driver, message)
      res.json { status: 0, id: doc._id }
  
  reply: (req, res) ->
    return res.json { status: 1 } unless req.json_data.id

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # service doesn't exist, already cancelled, etc
      return res.json({ status: 1 }) unless (doc && doc.state == 1)

      state = if req.json_data.accept then 2 else -1
      Service.collection.update({_id: req.current_user._id}, {$set: {state: state}})
    
      message =
        type: "call-taxi-reply"
        accept: req.json_data.accept
        id: doc._id
        timestamp: new Date().valueOf()

      User.send(doc.passenger, message)
      res.json { status: 0 }

  cancel: (req, res) ->
    return res.json { status: 1 } unless req.json_data.id

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # can't cancel completed service or rejected service
      return res.json { status: 1 } if doc.state == 3 || doc.state == -1

      Service.collection.update({_id: req.current_user._id}, {$set: {state: -2}})
      message =
        type: "call-taxi-cancel"
        id: doc._id
        timestamp: new Date().valueOf()

      User.send(doc.driver, message)
      res.json { status: 0 }

  complete: (req, res) ->
    return res.json { status: 1 } unless req.json_data.id

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # can only complete accepted service
      return res.json { status: 1 } unless doc.state == 2
      Service.collection.update({_id: req.current_user._id}, {$set: {state: -2}})

      message =
        type: "call-taxi-complete"
        id: doc._id
        timestamp: new Date().valueOf()

      User.send(doc.passenger, message)
      res.json { status: 0 }

module.exports = TaxiCallController
