# controllers for driver

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class DriverController

  constructor: ->

  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      winston.warn("driver", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }
  
  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
      winston.warn("driver signup - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
      winston.warn("driver signup - phone_number already registered:", req.json_data)
      return res.json { status: 3, message: "phone_number already registered." } if doc

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
        return res.json { status: 3, message: "incorrect credential" }

      req.session.user_id = driver.phone_number

      self = { phone_number: driver.phone_number, nickname: driver.nickname, state: driver.taxi_state, car_number: driver.car_number, state: driver.taxi_state }
      Service.collection.findOne { driver: driver.phone_number, $or:[{state: 1}, {state: 2}]}, (err, service) ->
        if err or !service
          winston.warn("driver signin", "database error")
          return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

        User.collection.findOne {phone_number: service.passenger}, (err, passenger) ->
          if err or !passenger
            winston.warn("can't find passenger #{service.passenger} for existing service", service)
            return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

          self.passenger =
            phone_number: passenger.phone_number
            nickname: passenger.nickname
            location: passenger.location
          self.id = service._id

          # { status: 0|1|2|... [, message: "xxxx"], self: {car_number:"xxx", nickname:"liufy", phone_number:"13814171931", state: 0|1, passenger: {nickname:"souriki", phone_number:"13913391280"[, latitude: 11.234567, longitude: 112.678901]}}
          res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    unless req.json_data.latitude && req.json_data.longitude
      winston.warn("driver updateLocation - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    loc =
      longitude: req.json_data.longitude
      latitude: req.json_data.latitude
    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find {driver: req.current_user.phone_number, state: 2}, (err, cursor) ->
      cursor.toArray (err, docs) ->
        for doc in docs
          message =
            receiver: doc.passenger
            type: "location-update"
            phone_number: req.current_user.phone_number
            location: loc
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
