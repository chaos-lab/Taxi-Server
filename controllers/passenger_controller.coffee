# controllers for passenger

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')
_ = require('underscore')

class PassengerController

  constructor: ->

  ##
  # passenger signup
  ##
  signup: (req, res) ->
    unless req.json_data && _.isString(req.json_data.phone_number) && !_.isEmpty(req.json_data.phone_number) &&
           _.isString(req.json_data.password) && !_.isEmpty(req.json_data.password) &&
           _.isString(req.json_data.name) && !_.isEmpty(req.json_data.name)
      logger.warning("passenger signup - incorrect data format %s", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {$or: [{phone_number: req.json_data.phone_number}, {name: req.json_data.name}]}, (err, doc) ->
      if doc
        if doc.phone_number == req.json_data.phone_number
          logger.warning("driver signup - phone_number already registered: %s", req.json_data)
          return res.json { status: 101, message: "phone_number already registered" }
        else
          logger.warning("driver signup - name is already taken: %s", req.json_data)
          return res.json { status: 102, message: "name is already taken" }

      data =
        phone_number: req.json_data.phone_number
        password: req.json_data.password
        name: req.json_data.name
        role: 1
        state: 0
      User.create(data)

      res.json { status: 0 }
  
  ##
  # passenger signin
  ##
  signin: (req, res) ->
    unless req.json_data && _.isString(req.json_data.phone_number) && !_.isEmpty(req.json_data.phone_number) &&
           _.isString(req.json_data.password) && !_.isEmpty(req.json_data.password)
      logger.warning("passenger signin - incorrect data format %s", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, passenger) ->
      unless passenger && req.json_data.password == passenger.password && passenger.role == 1
        logger.warning("passenger signin - incorrect credential %s", req.json_data)
        return res.json { status: 101, message: "incorrect credential" }

      # set session info
      req.session.user_name = passenger.name

      passenger.stats = {average_score: 0, service_count: 0, evaluation_count: 0} unless passenger.stats
      self = { phone_number: passenger.phone_number, name: passenger.name, stats: passenger.stats }
      Service.collection.findOne { passenger: passenger.name, $or:[{state: 1}, {state: 2}]}, (err, service) ->
        if err or !service
          self.state = 0
          return res.json { status: 0, self: self, message: "welcome, #{passenger.name}" }

        User.collection.findOne {name: service.driver}, (err, driver) ->
          if err or !driver
            logger.error("can't find driver #{service.driver} for existing service %s", service)
            self.state = 0
            return res.json { status: 0, self: self, message: "welcome, #{passenger.name}" }

          self.driver =
            car_number: driver.car_number
            phone_number: driver.phone_number
            name: driver.name
            location:
              longitude: driver.location[0]
              latitude: driver.location[1]
          self.state = if service.state == 1 then 1 else 2

          # { status: 0|1|2|... [, message: "xxxx"], self:{ name:"liufy", phone_number:"13814171931", state: 0|1|2, driver: {car_number:"a186", name: "liuq", phone_number: "12345678900"[, latitude: 11.456789, longitude: 211.211985]}}} 
          res.json { status: 0, self: self, message: "welcome, #{passenger.name}" }
  
  ##
  # passenger signout
  ##
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  ##
  # passenger update location
  ##
  updateLocation: (req, res) ->
    unless req.json_data && _.isNumber(req.json_data.latitude) && _.isNumber(req.json_data.longitude)
      return res.json { status: 2, message: "incorrect data format" }

    loc = [req.json_data.longitude, req.json_data.latitude]
    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find({passenger: req.current_user.name, state: 2}).toArray (err, docs) ->
      if err
        logger.error("passenger updateLocation - database error")
        return res.json { status: 3, message: "database error" }

      for doc in docs
        message =
          receiver: doc.driver
          type: "location-update"
          name: req.current_user.name
          location:
            longitude: req.json_data.longitude
            latitude: req.json_data.latitude
          timestamp: new Date().valueOf()

        Message.collection.update({receiver: message.receiver, name: message.name, type: message.type}, message, {upsert: true})

    res.json { status: 0 }
  
  ##
  # passenger get messages
  ##
  refresh: (req, res) ->
    User.getMessages req.current_user.name, (messages)->
        res.json { status: 0, messages: messages }

module.exports = PassengerController
