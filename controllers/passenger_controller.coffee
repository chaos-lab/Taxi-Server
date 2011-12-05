# controllers for passenger

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

class PassengerController

  constructor: ->

  restrict_to_passenger: (req, res, next) ->
    if (req.current_user && req.current_user.role == 1)
      next()
    else
      console.log('Unauthorized')
      res.json { status: 1, message: 'Unauthorized' }

  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
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
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, passenger) ->
      unless passenger && req.json_data.password == passenger.password && passenger.role == 1
        return res.json { status: 2, message: "incorrect credentials" }

      req.session.user_id = passenger.phone_number

      self = { phone_number: passenger.phone_number, nickname: passenger.nickname }
      Service.findOne { passenger: passenger.phone_number, state: 2}, (err, service) ->
        if err
          return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

        User.collection.findOne {phone_number: service.driver}, (err, driver) ->
          if err
            console.log("error: can't find passenger #{service.passenger}")
            return res.json { status: 0, self: self, message: "welcome, #{driver.nickname}" }

          service.driver = 
            phone_number: driver.phone_number
            nickname: driver.nickname
            location: driver.location
          self.service = service

          res.json { status: 0, self: self, message: "welcome, #{passenger.nickname}" }
  
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
