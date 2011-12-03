# taxi call controller

User = require('../models/user')
Service = require('../models/service')

class TaxiCallController
  constructor: ->

  getNearTaxis: (req, res) ->
    taxis = []
  
    User.collection.find { role: 2, state:{$gte: 1}, taxi_state:1 }, (err, cursor)->
      return res.json { status: 2, message: "database error"  } if err

      cursor.toArray (err, docs) ->
        return res.json { status: 2, message: "database error" } if err

        for doc in docs
          if doc.location
            taxis.push
              phone_number: doc.phone_number
              nickname: doc.nickname
              car_number: doc.car_number
              longitude: doc.location.longitude
              latitude: doc.location.latitude
  
        res.json { status: 0, taxis: taxis }
  
  create: (req, res) ->
    return res.json { status: 2, message: "incorrect data format" } unless req.json_data.driver

    User.collection.findOne {phone_number: req.json_data.driver}, (err, doc) ->
      if !doc || doc.state == 0 || doc.taxi_state != 1
         return res.json { status: 3, message: "driver can't accept taxi call for now" }

      Service.uniqueID (id)->
        data =
          driver: req.json_data.driver
          passenger: req.current_user.phone_number
          state: 1
          location: req.json_data.location
          key: req.json_data.key
          _id: id

        Service.create data

        message =
          type: "call-taxi"
          passenger:
            phone_number: req.current_user.phone_number
            nickname:req.current_user.nickname
          location: req.json_data.location
          id: id
          timestamp: new Date().valueOf()

        User.send(req.json_data.driver, message)
        res.json { status: 0, id: id }
  
  reply: (req, res) ->
    return res.json { status: 2, message: "incorrect data format" } unless req.json_data.id

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # service doesn't exist, already cancelled, etc
      unless doc && doc.state == 1
        return res.json { status: 3, message: "service can't be replied" }

      state = if req.json_data.accept then 2 else -1
      Service.collection.update({_id: req.json_data.id}, {$set: {state: state}})
    
      message =
        type: "call-taxi-reply"
        accept: req.json_data.accept
        key: doc.key
        timestamp: new Date().valueOf()

      User.send(doc.passenger, message)
      res.json { status: 0 }

  cancel: (req, res) ->
    if !req.json_data.id && !req.json_data.key
      return res.json { status: 2, message: "incorrect data format" }

    query = if req.json_data.id then {_id: req.json_data.id} else {key: req.json_data.key, passenger: req.current_user.phone_number}
    console.dir query

    Service.collection.findOne query, (err, doc) ->
      # can't cancel completed service or rejected service
      if !doc || doc.state == 3 || doc.state == -1
        return res.json { status: 3, message: "service can't be cancelled" }

      Service.collection.update({_id: doc._id}, {$set: {state: -2}})
      message =
        type: "call-taxi-cancel"
        id: doc._id
        timestamp: new Date().valueOf()

      User.send(doc.driver, message)
      res.json { status: 0 }

  complete: (req, res) ->
    return res.json { status: 2, message: "incorrect data format" } unless req.json_data.id

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # can only complete accepted service
      return res.json { status: 3, message: "only accepted service can be completed" } unless doc.state == 2
      Service.collection.update({_id: doc._id}, {$set: {state: -2}})

      message =
        type: "call-taxi-complete"
        key: doc.key
        timestamp: new Date().valueOf()

      User.send(doc.passenger, message)
      res.json { status: 0 }

module.exports = TaxiCallController
