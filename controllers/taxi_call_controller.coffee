# taxi call controller

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class TaxiCallController
  constructor: ->

  getNearTaxis: (req, res) ->
    taxis = []

    User.collection.find({ role:2, state:{$gte: 1}, taxi_state:1 }).toArray (err, docs)->
      if err
        winston.warn("Service getNearTaxis - database error")
        return res.json { status: 3, message: "database error" }

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
    unless req.json_data.driver
      winston.warn("Service create - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.driver}, (err, doc) ->
      if !doc || doc.state == 0 || doc.taxi_state != 1
         winston.warn("Service create - driver #{req.json_data.driver} can't accept taxi call for now", doc)
         return res.json { status: 101, message: "driver can't accept taxi call for now" }

      # only one active service is allowed for a user at the same time
      Service.collection.findOne {passenger: req.current_user.phone_number, $or:[{state:1}, {state:2}]}, (err, doc) ->
        # cancel existing services
        if doc
          Service.collection.update({_id: doc._id}, {$set: {state: -2}})
          # send cancel message to driver
          message =
            receiver: doc.driver
            type: "call-taxi-cancel"
            id: doc._id
            timestamp: new Date().valueOf()
          Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

        # create new service
        Service.uniqueID (id)->
          data =
            driver: req.json_data.driver
            passenger: req.current_user.phone_number
            state: 1
            origin: (req.json_data.origin || req.current_user.location)
            destination: req.json_data.destination
            key: req.json_data.key
            _id: id
          Service.create data

          # send call-taxi message to driver
          message =
            receiver: req.json_data.driver
            type: "call-taxi"
            passenger:
              phone_number: req.current_user.phone_number
              nickname:req.current_user.nickname
            origin: req.json_data.origin
            destination: req.json_data.destination
            id: id
            timestamp: new Date().valueOf()
          Message.collection.update({receiver: message.receiver, passenger:message.passenger, type: message.type}, message, {upsert: true})

          res.json { status: 0, id: id }

  reply: (req, res) ->
    unless req.json_data.id
      winston.warn("Service reply - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # service doesn't exist, already cancelled, etc
      unless doc && doc.state == 1
        winston.warn("Service reply - service can't be replied", doc)
        return res.json { status: 101, message: "service can't be replied" }

      state = if req.json_data.accept then 2 else -1
      Service.collection.update({_id: req.json_data.id}, {$set: {state: state, updated_at: new Date()}})
      # set taxi state to running
      User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: 2}}) if req.json_data.accept

      message =
        receiver: doc.passenger
        type: "call-taxi-reply"
        accept: req.json_data.accept
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      res.json { status: 0 }

  cancel: (req, res) ->
    if !req.json_data.id && !req.json_data.key
      winston.warn("Service cancel - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    query = if req.json_data.id then {_id: req.json_data.id} else {key: req.json_data.key, passenger: req.current_user.phone_number}

    Service.collection.findOne query, (err, doc) ->
      # can't cancel completed service or rejected service
      if !doc || doc.state == 3 || doc.state == -1
        winston.warn("Service reply - service can't be cancelled", doc)
        return res.json { status: 101, message: "service can't be cancelled" }

      # update service state
      Service.collection.update({_id: doc._id}, {$set: {state: -2, updated_at: new Date()}})
      # remove call-taxi message if it's not sent
      Message.collection.remove({receiver: doc.driver, id: doc._id, type: "call-taxi"})

      message =
        receiver: doc.driver
        type: "call-taxi-cancel"
        id: doc._id
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

      res.json { status: 0 }

  complete: (req, res) ->
    unless req.json_data.id
      winston.warn("Service complete - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # can only complete accepted service
      unless doc.state == 2
        winston.warn("Service complete - service can't be completed", doc)
        return res.json { status: 101, message: "only accepted service can be completed" }
      Service.collection.update({_id: doc._id}, {$set: {state: 3, updated_at: new Date()}})
      # set taxi state to idle
      User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: 1}})

      message =
        receiver: doc.passenger
        type: "call-taxi-complete"
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      res.json { status: 0 }

module.exports = TaxiCallController
