express = require('express')
crypto = require('crypto')
_ = require('./underscore')

drivers = {}
passengers = {}

######################################################
# create express
######################################################
module.exports = app = express.createServer()
app.start = ->
  app.listen config.webserver.port, ->
    addr = app.address()
    console.log('app listening on http://' + addr.address + ':' + addr.port)

######################################################
# configurations
######################################################
app.configure ->
  # session support
  app.use(express.logger())
  app.use(express.bodyParser())
  app.use(express.cookieParser())
  app.use(express.session({ secret: "keyboard cat" }))

  app.use express.errorHandler
    dumpExceptions: true
    showStack : true

######################################################
# utility functions
######################################################
make_salt = ->
  return Math.round((new Date().valueOf() * Math.random())) + ''

######################################################
# preprocess json data
######################################################
app.use (req, res, next) ->
  if req.param("json_data")
    req.json_data = JSON.parse(req.param("json_data"))
  next()

restrict_to_driver = (req, res, next) ->
  if (req.session.user && req.session.user.type == "driver")
    req.current_user = drivers[req.session.user.phone_number]
    next()
  else
    res.json { status: 1, message: 'Unauthorized' }

restrict_to_passenger = (req, res, next) ->
  if (req.session.user && req.session.user.type == "passenger")
    req.current_user = passengers[req.session.user.phone_number]
    next()
  else
    res.json { status: 1, message: 'Unauthorized' }

# debug routes
app.get '/', (req, res, next)->
  res.json { status: 0, message:"hello, world!" }

######################################################
# driver routes
######################################################
app.post '/driver/signup', (req, res) ->
  if req.json_data.phone_number && req.json_data.password && req.json_data.nickname && req.json_data.car_number
    req.json_data.salt = make_salt()
    req.json_data.password = crypto.createHmac('sha1', req.json_data.salt).update(req.json_data.password).digest('hex')
    req.json_data.messages = []
    drivers[req.json_data.phone_number] = req.json_data
    res.json { status: 0 }
  else
    res.json { status: 1 }

app.post '/driver/signin', (req, res) ->
  if req.json_data.phone_number && req.json_data.password
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
    res.json { status: 2 }

app.post '/driver/signout', restrict_to_driver, (req, res) ->
  req.current_user.status = 0
  req.session.destroy()
  res.json { status: 0, message: "bye" }

app.post '/driver/location/update', restrict_to_driver, (req, res) ->
  req.current_user.location = req.json_data
  res.json { status: 0 }

# TODO add real-time status update. Use refresh as heart-beat
app.get '/driver/refresh', restrict_to_driver, (req, res) ->
  res.json { status: 0, messages: req.current_user.messages }
  req.current_user.messages = []
  req.current_user.status = 2

app.post '/driver/message', restrict_to_driver, (req, res) ->
  if req.current_user.phone_number == req.json_data.from && passengers[req.json_data.to]
    passengers[req.json_data.to].messages.push(req.json_data)
    res.json { status: 0 }
  else
    res.json { status: 1 }

######################################################
# passenger routes
######################################################
app.post '/passenger/signup', (req, res) ->
  if req.json_data.phone_number && req.json_data.password && req.json_data.nickname
    req.json_data.salt = make_salt()
    req.json_data.password = crypto.createHmac('sha1', req.json_data.salt).update(req.json_data.password).digest('hex')
    req.json_data.messages = []
    passengers[req.json_data.phone_number] = req.json_data
    res.json { status: 0 }
  else
    res.json { status: 1 }

app.post '/passenger/signin', (req, res) ->
  if req.json_data.phone_number && req.json_data.password
     current_user = passengers[req.json_data.phone_number]
     password = crypto.createHmac('sha1', current_user.salt).update(req.json_data.password).digest('hex')

     if password == current_user.password
       req.session.user = { phone_number: current_user.phone_number, type: "passenger" }
       current_user.status = 1
       self = { phone_number: current_user.phone_number, nickname: current_user.nickname }
       res.json { status: 0, self: self, message: "welcome, #{current_user.nickname}" }
     else
       res.json { status: 1 }

  else
    res.json { status: 1 }

# TODO find the nearest taxi
app.get '/passenger/taxi/near', restrict_to_passenger, (req, res) ->
  taxis = []

  _.each drivers, (driver, phone) ->
    if driver.status > 0 && driver.location
      taxis.push
        phone_number: driver.phone_number
        nickname: driver.nickname
        car_number: driver.car_number
        longitude: driver.location.longitude
        latitude: driver.location.latitude

  res.json { status: 0, taxis: taxis }


app.post '/passenger/signout', restrict_to_passenger, (req, res) ->
  req.current_user.status = 0
  req.session.destroy()
  res.json { status: 0, message: "bye" }

app.post '/passenger/location/update', restrict_to_passenger, (req, res) ->
  req.current_user.location = req.json_data
  res.json { status: 0 }

app.post '/passenger/message', restrict_to_passenger, (req, res) ->
  if req.current_user.phone_number == req.json_data.from && drivers[req.json_data.to]
    drivers[req.json_data.to].messages.push(req.json_data)
    res.json { status: 0 }
  else
    res.json { status: 1 }

# TODO add real-time status update. Use refresh as heart-beat
app.get '/passenger/refresh', restrict_to_passenger, (req, res) ->
  res.json { status: 0, messages: req.current_user.messages }
  req.current_user.messages = []
  req.current_user.status = 2

