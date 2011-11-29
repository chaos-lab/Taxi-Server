express = require('express')

######################################################
# mongodb setup
######################################################
mongodb = require('mongodb')
server = new mongodb.Server(config.database.host, config.database.port, {})

######################################################
# initiate models
######################################################
User = require('./models/user')
Service = require('./models/service')

######################################################
# controllers
######################################################
DriverController = require('./controllers/driver_controller')
driver_controller = new DriverController()

PassengerController = require('./controllers/passenger_controller')
passenger_controller = new PassengerController()

TaxiCallController = require('./controllers/taxi_call_controller')
taxi_call_controller = new TaxiCallController()

######################################################
# create express
######################################################
module.exports = app = express.createServer()
app.start = ->
  new mongodb.Db(config.database.db, server, {}).open (error, client)->
    throw error if error

    User.setup(client)
    Service.setup(client)

    app.listen config.webserver.port, ->
      addr = app.address()
      console.log('app listening on http://' + addr.address + ':' + addr.port)

######################################################
# configurations
######################################################
app.configure ->
  app.use(express.profiler())
  # session support
  app.use(express.bodyParser())
  app.use(express.cookieParser())
  app.use(express.session({ secret: "keyboard cat" }))

  app.use(express.logger())
  app.use express.errorHandler
    dumpExceptions: true
    showStack : true

######################################################
# preprocess json data
######################################################
app.use (req, res, next) ->
  if req.param("json_data")
    req.json_data = JSON.parse(req.param("json_data"))

  if req.session.user_id
    User.collection.findOne { phone_number: req.session.user_id }, {}, (err, doc)->
      if doc
        User.collection.update {_id: doc.id}, {$set: {last_active_at: new Date(), state: 2}}
        req.current_user = doc

      next()
  else
    next()

# debug routes
app.get '/', (req, res, next)->
  res.json { status: 0, message:"hello, world!" }

######################################################
# driver routes
######################################################
app.post '/driver/signup',          driver_controller.signup
app.post '/driver/signin',          driver_controller.signin
app.post '/driver/signout',         driver_controller.restrict_to_driver,   driver_controller.signout
app.post '/driver/location/update', driver_controller.restrict_to_driver,   driver_controller.updateLocation
app.post '/driver/taxi/update',     driver_controller.restrict_to_driver,   driver_controller.updateState
app.get  '/driver/refresh',         driver_controller.restrict_to_driver,   driver_controller.refresh

######################################################
# passenger routes
######################################################
app.post '/passenger/signup',           passenger_controller.signup
app.post '/passenger/signin',           passenger_controller.signin
app.post '/passenger/signout',          passenger_controller.restrict_to_passenger,   passenger_controller.signout
app.post '/passenger/location/update',  passenger_controller.restrict_to_passenger,   passenger_controller.updateLocation
app.get  '/passenger/refresh',          passenger_controller.restrict_to_passenger,   passenger_controller.refresh

######################################################
# taxi call routes
######################################################
app.get  '/taxi/near',           passenger_controller.restrict_to_passenger, taxi_call_controller.getNearTaxis
app.post '/service/create',      passenger_controller.restrict_to_passenger, taxi_call_controller.create
app.post '/service/reply',       driver_controller.restrict_to_driver,       taxi_call_controller.reply
app.post '/service/cancel',      passenger_controller.restrict_to_passenger, taxi_call_controller.cancel
app.post '/service/complete',    driver_controller.restrict_to_driver,       taxi_call_controller.complete

