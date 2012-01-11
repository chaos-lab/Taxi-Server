# controllers for driver

class DriverController

  constructor: ->

  ##
  # driver sign up
  ##
  signup: (req, res) ->
    unless req.json_data && _.isString(req.json_data.phone_number) && !_.isEmpty(req.json_data.phone_number) &&
           _.isString(req.json_data.password) && !_.isEmpty(req.json_data.password) &&
           _.isString(req.json_data.name) && !_.isEmpty(req.json_data.name) &&
           _.isString(req.json_data.car_number) && !_.isEmpty(req.json_data.car_number)
      logger.warning("driver signup - incorrect data format %s", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    data =
      phone_number: req.json_data.phone_number
      password: req.json_data.password
      name: req.json_data.name
      car_number: req.json_data.car_number
      role: ["user", "driver"]
      state: 0
      taxi_state: 1

    User.signup data, (result)->
      res.json result
  
  ##
  # driver sign in
  ##
  signin: (req, res) ->
    unless req.json_data && _.isString(req.json_data.phone_number) && !_.isEmpty(req.json_data.phone_number) &&
           _.isString(req.json_data.password) && !_.isEmpty(req.json_data.password)
      logger.warning("driver signin - incorrect data format %s", req.json_data)
      return res.json({ status: 2, message: "incorrect data format" })

    User.signin req.json_data, (driver)->
      unless driver && req.json_data.password == driver.password && _.include(driver.role, "driver")
        logger.warning("driver signin - incorrect credential %s", req.json_data)
        return res.json { status: 101, message: "incorrect credential" }

      # set session info
      req.session.user_name = driver.name

      # send taxi-call of initiated service to driver
      Service.collection.find({ driver: driver.name, state: 1 }).toArray (err, docs) ->
        if err
          logger.warning("driver signin - database error")
          return res.json { status: 3, message: "database error" }

        for doc in docs
          User.collection.findOne {name: doc.passenger}, (err, passenger) ->
            message =
              receiver: doc.driver
              type: "call-taxi"
              passenger:
                phone_number: passenger.phone_number
                name: passenger.name
              origin:
                longitude: doc.origin[0]
                latitude: doc.origin[1]
                name: doc.origin[2]
              id: doc._id
              timestamp: new Date().valueOf()
            message.destination = {longitude: doc.destination[0], latitude: doc.destination[1], name: doc.destination[2]} if doc.destination
            Message.collection.update({receiver: message.receiver, passenger:message.passenger, type: message.type}, message, {upsert: true})

      # find accepted service, and include the info in response
      driver.stats = {average_score: 0, service_count: 0, evaluation_count: 0} unless driver.stats
      self = { phone_number: driver.phone_number, name: driver.name, state: driver.taxi_state, car_number: driver.car_number, state: driver.taxi_state, stats: driver.stats }
      Service.collection.findOne { driver: driver.name, state: 2 }, (err, service) ->
        if !service
          return res.json { status: 0, self: self, message: "welcome, #{driver.name}" }

        User.collection.findOne {name: service.passenger}, (err, passenger) ->
          if err or !passenger
            logger.error("can't find passenger #{service.passenger} for existing service %s", service)
            return res.json { status: 0, self: self, message: "welcome, #{driver.name}" }

          self.passenger =
            phone_number: passenger.phone_number
            name: passenger.name
            location:
              longitude: passenger.location[0]
              latitude: passenger.location[1]
          self.id = service._id

          res.json { status: 0, self: self, message: "welcome, #{driver.name}" }
  
  ##
  # driver sign out
  ##
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  ##
  # driver update location
  ##
  updateLocation: (req, res) ->
    unless req.json_data && _.isNumber(req.json_data.latitude) && _.isNumber(req.json_data.longitude)
      logger.warning("driver updateLocation - incorrect data format %s", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    loc = [req.json_data.longitude, req.json_data.latitude]
    User.collection.update {_id: req.current_user._id}, {$set: {location: loc}}

    Service.collection.find({driver: req.current_user.name, state: 2}).toArray (err, docs) ->
      if err
        logger.error("driver updateLocation - database error")
        return res.json { status: 3, message: "database error" }

      for doc in docs
        message =
          receiver: doc.passenger
          type: "location-update"
          name: req.current_user.name
          location:
            longitude: req.json_data.longitude
            latitude: req.json_data.latitude
          timestamp: new Date().valueOf()

        Message.collection.update({receiver: message.receiver, name: message.name, type: message.type}, message, {upsert: true})

    res.json { status: 0 }

  ##
  # driver update taxi state
  ##
  updateState: (req, res) ->
    unless req.json_data && _.isNumber(req.json_data.state)
      logger.warning("driver updateState - incorrect data format %s", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: req.json_data.state}})
    res.json { status: 0 }
  
  ##
  # driver get messages
  ##
  refresh: (req, res) ->
    User.getMessages req.current_user.name, (messages)->
      res.json { status: 0, messages: messages }

module.exports = DriverController
