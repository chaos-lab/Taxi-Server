# controllers for driver

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class DriverController

  constructor: ->

  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      console.log('Unauthorized')
      res.json { status: 1, message: 'Unauthorized' }
  
  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
       return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
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
      return res.json({ status: 2, message: "incorrect data format" })

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, driver) ->
      unless driver && req.json_data.password == driver.password && driver.role == 2
        return res.json { status: 3, message: "incorrect credential" }

      req.session.user_id = driver.phone_number

      self = { phone_number: driver.phone_number, nickname: driver.nickname, state: driver.taxi_state }
      Service.findOne { driver: driver.phone_number, state: 2}, (err, service) ->
        if err
          return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

        User.collection.findOne {phone_number: service.passenger}, (err, passenger) ->
          if err
            console.log("error: can't find passenger #{service.passenger}")
            return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

          service.passenger =
            phone_number: passenger.phone_number
            nickname: passenger.nickname
            location: passenger.location
          self.service = service

          res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    unless req.json_data.latitude && req.json_data.longitude
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
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: req.json_data.state}})
    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.getMessages req.current_user.phone_number, (messages)->
      res.json { status: 0, messages: messages }

module.exports = DriverController
