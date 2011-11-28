# controllers for driver

User = require('../models/user')

class DriverController

  constructor: ->

  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      res.json { status: 1, message: 'Unauthorized' }
  
  signup: (req, res) ->
    if req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
      req.json_data.messages = []
      req.json_data.role = 2
      User.create(req.json_data)
      res.json { status: 0 }
    else
      res.json { status: 1 }
  
  signin: (req, res) ->
    if req.json_data.phone_number && req.json_data.password && drivers[req.json_data.phone_number]

       User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
         return res.json { status: 1 } if err

         if password == doc.password && doc.role == 2
           req.session.user_id = doc._id
           User.collection.update({_id: doc._id}, {$set: {state: 1}})

           self = { phone_number: doc.phone_number, nickname: doc.nickname }
           res.json { status: 0, self: self, message: "welcome, #{current_user.nickname}" }
         else
           res.json { status: 1 }
    else
      res.json { status: 1 }
  
  signout: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: 0}})
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  # TODO send LocationUpdate message to passengers
  updateLocation: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {location: req.json_data}})
    res.json { status: 0 }
  
  updateState: (req, res) ->
    User.collection.update({_id: req.current_user._id}, {$set: {state: req.json_data.state}})
    res.json { status: 0 }
  
  # TODO add real-time status update. Use refresh as heart-beat
  refresh: (req, res) ->
    res.json { status: 0, messages: req.current_user.messages }
    User.collection.update({_id: req.current_user._id}, {$set: {messages: [], state: 2}})

module.exports = DriverController
