# controllers for driver

User = require('./user')

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
      User.create(req.json_data)
      res.json { status: 0 }
    else
      res.json { status: 1 }
  
  signin: (req, res) ->
    if req.json_data.phone_number && req.json_data.password && drivers[req.json_data.phone_number]
       current_user = drivers[req.json_data.phone_number]
       password = crypto.createHmac('sha1', current_user.salt).update(req.json_data.password).digest('hex')
  
       if password == current_user.password
         req.session.user = { phone_number: current_user.phone_number, type: "driver" }
         current_user.status = 1
         self = { phone_number: current_user.phone_number, nickname: current_user.nickname, car_number: current_user.car_number }
         res.json { status: 0, self: self, message: "welcome, #{current_user.nickname}" }
       else
         res.json { status: 1 }
    else
      res.json { status: 1 }
  
  signout: (req, res) ->
    req.current_user.status = 0
    req.session.destroy()
    res.json { status: 0, message: "bye" }
  
  updateLocation: (req, res) ->
    req.current_user.location = req.json_data
    res.json { status: 0 }
  
  updateState: (req, res) ->
    req.current_user.state = req.state
    res.json { status: 0 }
  
  # TODO add real-time status update. Use refresh as heart-beat
  refresh: (req, res) ->
    res.json { status: 0, messages: req.current_user.messages }
    req.current_user.messages = []
    req.current_user.status = 2
  
exports.DriverController = DriverController
