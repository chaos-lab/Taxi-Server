# controllers for passenger

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class PassengerController

  constructor: ->

  restrict_to_passenger: (req, res, next) ->
    if (req.current_user && req.current_user.role == 1)
      next()
    else
      winston.warn("passenger", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname
      winston.warn("passenger signup - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
      winston.warn("passenger signup", "phone_number already registered:", req.json_data)
      return res.json { status: 3, message: "phone_number already registered." } if doc

      data =
        phone_number: req.json_data.phone_number
        password: req.json_data.password
        nickname: req.json_data.nickname
        role: 1
        state: 0
      User.create(data)

      res.json { status: 0 }
  
  signin: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password
      winston.warn("passenger signin - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, passenger) ->
      unless passenger && req.json_data.password == passenger.password && passenger.role == 1
        winston.warn("passenger signin - incorrect credential", req.json_data)
        return res.json { status: 2, message: "incorrect credentials" }

      req.session.user_id = passenger.phone_number

      self = { phone_number: passenger.phone_number, nickname: passenger.nickname }
      Service.collection.findOne { passenger: passenger.phone_number, state: 2}, (err, service) ->
        if err
          self.state = 0
          return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

        User.collection.findOne {phone_number: service.driver}, (err, driver) ->
          if err or !driver
            winston.warn("can't find driver #{service.driver} for existing service", service)
            self.state = 0
            return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

          self.driver =
            car_number: driver.car_number
            phone_number: driver.phone_number
            nickname: driver.nickname
            location: driver.location
          self.state = 1

          # { status: 0|1|2|... [, message: "xxxx"], self:{ nickname:"liufy", phone_number:"13814171931", state: 0|1|2, driver: {car_number:"a186", nickname: "liuq", phone_number: "12345678900"[, latitude: 11.456789, longitude: 211.211985]}}} 
          res.json { status: 0, self: self, message: "welcome, #{passenger.nickname}" }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    unless req.json_data.latitude && req.json_data.longitude
      winston.warn("passenger updateLocation - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    loc =
      longitude: req.json_data.longitude
      latitude: req.json_data.latitude

    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find {passenger: req.current_user.phone_number, state: 2}, (err, cursor) ->
      cursor.toArray (err, docs) ->
        for doc in docs
          message =
            receiver: doc.driver
            type: "location-update"
            phone_number: req.current_user.phone_number
            location: loc
            timestamp: new Date().valueOf()

          Message.collection.update({receiver: message.receiver, phone_number: message.phone_number, type: message.type}, message, {upsert: true})

    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.getMessages req.current_user.phone_number, (messages)->
        res.json { status: 0, messages: messages }

module.exports = PassengerController
