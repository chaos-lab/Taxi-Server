# controllers for driver

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class DriverController

  constructor: ->

  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
      winston.warn("driver signup - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {$or: [{phone_number: req.json_data.phone_number}, {nickname: req.json_data.nickname}]}, (err, doc) ->
      if doc
        if doc.phone_number == req.json_data.phone_number
          winston.warn("driver signup - phone_number already registered:", req.json_data)
          return res.json { status: 101, message: "phone_number already registered" }
        else
          winston.warn("driver signup - nickname is already taken:", req.json_data)
          return res.json { status: 102, message: "nickname is already taken" }

      data =
        phone_number: req.json_data.phone_number
        password: req.json_data.password
        nickname: req.json_data.nickname
        car_number: req.json_data.car_number
        role: 2
        state: 0
        taxi_state: 1

      User.create(data)

      res.json { status: 0 }
  
  signin: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password
      winston.warn("driver signin - incorrect data format", req.json_data)
      return res.json({ status: 2, message: "incorrect data format" })

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, driver) ->
      unless driver && req.json_data.password == driver.password && driver.role == 2
        winston.warn("driver signin - incorrect credential", req.json_data)
        return res.json { status: 101, message: "incorrect credential" }

      # set session info
      req.session.user_id = driver.phone_number

      # send taxi-call of initiated service to driver
      Service.collection.find({ driver: driver.phone_number, state: 1 }).toArray (err, docs) ->
        if err
          winston.warn("driver signin - database error")
          return res.json { status: 3, message: "database error" }

        for doc in docs
          User.collection.findOne {phone_number: doc.passenger}, (err, passenger) ->
            destination = if doc.destination then {longitude: doc.destination[0], latitude: doc.destination[1], name: doc.destination[2]} else null
            message =
              receiver: doc.driver
              type: "call-taxi"
              passenger:
                phone_number: passenger.phone_number
                nickname: passenger.nickname
              origin:
                longitude: doc.origin[0]
                latitude: doc.origin[1]
                name: doc.origin[2]
              destination: destination
              id: doc._id
              timestamp: new Date().valueOf()
            Message.collection.update({receiver: message.receiver, passenger:message.passenger, type: message.type}, message, {upsert: true})

      # find accepted service, and include the info in response
      self = { phone_number: driver.phone_number, nickname: driver.nickname, state: driver.taxi_state, car_number: driver.car_number, state: driver.taxi_state }
      Service.collection.findOne { driver: driver.phone_number, state: 2 }, (err, service) ->
        if !service
          return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

        User.collection.findOne {phone_number: service.passenger}, (err, passenger) ->
          if err or !passenger
            winston.warn("can't find passenger #{service.passenger} for existing service", service)
            return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

          self.passenger =
            phone_number: passenger.phone_number
            nickname: passenger.nickname
            location:
              longitude: passenger.location[0]
              latitude: passenger.location[1]
          self.id = service._id

          res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    unless req.json_data.latitude && req.json_data.longitude
      winston.warn("driver updateLocation - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    loc = [req.json_data.longitude, req.json_data.latitude]
    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find({driver: req.current_user.phone_number, state: 2}).toArray (err, docs) ->
      if err
        winston.warn("driver updateLocation - database error")
        return res.json { status: 3, message: "database error" }

      for doc in docs
        message =
          receiver: doc.passenger
          type: "location-update"
          phone_number: req.current_user.phone_number
          location:
            longitude: req.json_data.longitude
            latitude: req.json_data.latitude
          timestamp: new Date().valueOf()

        Message.collection.update({receiver: message.receiver, phone_number: message.phone_number, type: message.type}, message, {upsert: true})

    res.json { status: 0 }

  updateState: (req, res) ->
    unless req.json_data.state
      winston.warn("driver updateState - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: req.json_data.state}})
    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.getMessages req.current_user.phone_number, (messages)->
      res.json { status: 0, messages: messages }

module.exports = DriverController
