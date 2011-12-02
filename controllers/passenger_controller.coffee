# controllers for passenger

User = require('../models/user')

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

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
      unless doc && req.json_data.password == doc.password && doc.role == 1
        return res.json { status: 2, message: "incorrect credentials" }

      req.session.user_id = doc.phone_number
      User.collection.update {_id: doc._id}, {$set: {state: 1}}

      self = { phone_number: doc.phone_number, nickname: doc.nickname }
      res.json { status: 0, self: self, message: "welcome, #{doc.nickname}" }
  
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
    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.collection.update {_id: req.current_user._id}, {$set: {messages: []}}
    res.json { status: 0, messages: req.current_user.messages || [] }

module.exports = PassengerController
