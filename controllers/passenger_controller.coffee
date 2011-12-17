# controllers for passenger

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class PassengerController

  constructor: ->

  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname
      winston.warn("passenger signup - incorrect data format", req.json_data)
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
        return res.json { status: 101, message: "incorrect credential" }

      # set session info
      req.session.user_id = passenger.phone_number

      self = { phone_number: passenger.phone_number, nickname: passenger.nickname }
      Service.collection.findOne { passenger: passenger.phone_number, $or:[{state: 1}, {state: 2}]}, (err, service) ->
        if err or !service
          self.state = 0
          return res.json { status: 0, self: self, message: "welcome, #{passenger.nickname}" }

        User.collection.findOne {phone_number: service.driver}, (err, driver) ->
          if err or !driver
            winston.warn("can't find driver #{service.driver} for existing service", service)
            self.state = 0
            return res.json { status: 0, self: self, message: "welcome, #{passenger.nickname}" }

          self.driver =
            car_number: driver.car_number
            phone_number: driver.phone_number
            nickname: driver.nickname
            location:
              longitude: driver.location[0]
              latitude: driver.location[1]
          self.state = if service.state == 1 then 1 else 2

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

    loc = [req.json_data.longitude, req.json_data.latitude]
    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find({passenger: req.current_user.phone_number, state: 2}).toArray (err, docs) ->
      if err
        winston.warn("passenger updateLocation - database error")
        return res.json { status: 3, message: "database error" }

      for doc in docs
        message =
          receiver: doc.driver
          type: "location-update"
          phone_number: req.current_user.phone_number
          location:
            longitude: req.json_data.longitude
            latitude: req.json_data.latitude
          timestamp: new Date().valueOf()

        Message.collection.update({receiver: message.receiver, phone_number: message.phone_number, type: message.type}, message, {upsert: true})

    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.getMessages req.current_user.phone_number, (messages)->
        res.json { status: 0, messages: messages }

module.exports = PassengerController
