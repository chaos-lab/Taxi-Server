# controllers for driver

User = require('../models/user')
Service = require('../models/service')

class DriverController

  constructor: ->

  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      res.json { status: 1, message: 'Unauthorized' }
  
  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
       return res.json { status: 1 }

    req.json_data.role = 2
    req.json_data.state = 0
    req.json_data.taxi_state = 1

    User.create(req.json_data)

    res.json { status: 0 }
  
  signin: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password
      return res.json({ status: 1 })

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
      unless doc && req.json_data.password == doc.password && doc.role == 2
        return res.json { status: 1 }

      req.session.user_id = doc.phone_number
      User.collection.update({_id: doc._id}, {$set: {state: 1}})

      self = { phone_number: doc.phone_number, nickname: doc.nickname }
      res.json { status: 0, self: self, message: "welcome, #{doc.nickname}" }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {location: req.json_data}})

    message =
      type: "location-update"
      phone_number: req.current_user.phone_number
      location: req.json_data
      timestamp: new Date().valueOf()

    Service.collection.find {driver: req.current_user.phone_number, state: 2}, {}, (err, docs) ->
      User.send(doc.passenger, message) for doc in docs

    res.json { status: 0 }

  updateState: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: req.json_data.state}})
    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.collection.update {_id: req.current_user._id}, {$set: {messages: []}}
    res.json { status: 0, messages: req.current_user.messages || [] }

module.exports = DriverController
