# controllers for passenger

User = require('../models/user')

class PassengerController

  constructor: ->

  restrict_to_passenger: (req, res, next) ->
    if (req.current_user && req.current_user.role == 1)
      next()
    else
      res.json { status: 1, message: 'Unauthorized' }

  signup: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password && req.json_data.nickname
      return res.json { status: 1 }

    req.json_data.role = 1
    req.json_data.state = 0
    User.create(req.json_data)

    res.json { status: 0 }
  
  signin: (req, res) ->
    unless req.json_data.phone_number && req.json_data.password
      return res.json({ status: 1 })

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, doc) ->
      unless doc && req.json_data.password == doc.password && doc.role == 1
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
    res.json { status: 0 }
  
  refresh: (req, res) ->
    User.collection.update {_id: req.current_user._id}, {$set: {messages: []}}
    res.json { status: 0, messages: req.current_user.messages || [] }

module.exports = PassengerController
