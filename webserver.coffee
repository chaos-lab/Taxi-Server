express = require('express')
mongodb = require('mongodb')
mongoStore = require('connect-mongodb')
Logger = require('log')
fs = require('fs')

######################################################
# logger modification to support object params
######################################################
log_old = Logger.prototype.log
Logger.prototype.log = ->
  args = []
  for arg in arguments[1]
    arg = JSON.stringify(arg) if typeof(arg) == 'object'
    args.push(arg)
  arguments[1] = args
  log_old.apply(this, arguments)

######################################################
# mongodb setup
######################################################
db = new mongodb.Db(config.database.db, new mongodb.Server(config.database.host, config.database.port,{auto_reconnect: true, poolSize: 4}))

######################################################
# initiate models
######################################################
User = require('./models/user')
Service = require('./models/service')
Message = require('./models/message')
Evaluation = require('./models/evaluation')
Location = require('./models/location')

User.setup(db)
Service.setup(db)
Message.setup(db)
Evaluation.setup(db)
Location.setup(db)
######################################################
# controllers
######################################################
AuthorizationController = require('./controllers/authorization_controller')
DriverController = require('./controllers/driver_controller')
PassengerController = require('./controllers/passenger_controller')
TaxiCallController = require('./controllers/taxi_call_controller')
LocationController = require('./controllers/location_controller')

authorizationController = new AuthorizationController
driverController = new DriverController
passengerController = new PassengerController
taxiCallController = new TaxiCallController
locationController = new LocationController

######################################################
# create express
######################################################
module.exports = app = express.createServer()

app.start = ->
  app.db.open ->
    app.listen config.webserver.port, ->
      addr = app.address()
      logger.info('app listening on http://' + addr.address + ':' + addr.port)

app.db = db
######################################################
# configurations
######################################################
app.configure ->
  app.use(express.bodyParser())
  app.use(express.cookieParser())
  app.use express.session
    secret: "keyboard cat"
    maxAge: 60000 * 20
    store: new mongoStore({db: db})

  app.use express.errorHandler
    dumpExceptions: true
    showStack : true

app.configure 'test', ->
  global.logger = new Logger('info', fs.createWriteStream('test.log'))

app.configure 'development', 'production', ->
  # for logging
  global.logger = new Logger('info')
  # stub logger to use with logger middleware
  logger.write = (data) -> logger.info(data)
  app.use(express.logger({stream: logger}))

  # don't use scheduler while test
  require('./controllers/scheduler')

  # logging params & response
  app.use (req, res, next) ->
    res.on "finish", ->
      logger.info("params:", req.json_data) if req.json_data

    stub = res.json
    res.json = (data) ->
      logger.info("response:", data)
      stub.apply(res, [data])

    next()

######################################################
# preprocess json data
######################################################
app.use (req, res, next) ->
  if req.param("json_data")
    try
      req.json_data = JSON.parse(req.param("json_data"))
    catch e
      return res.json {status: 2, message:"incorrect format in preprocessing"}

  unless req.session.user_name
    return next()

  User.collection.findOne { name: req.session.user_name }, {}, (err, doc)->
    if doc
      User.collection.update {_id: doc._id}, {$set: {last_active_at: new Date(), state: 2}}
      req.current_user = doc

    next()

# debug routes
app.get '/', (req, res, next)->
  res.json { status: 0, message:"hello, world!" }

######################################################
# driver routes
######################################################
app.post '/driver/signup',          driverController.signup
app.post '/driver/signin',          driverController.signin
app.post '/driver/signout',         authorizationController.restrict_to("driver"),   driverController.signout
app.post '/driver/location/update', authorizationController.restrict_to("driver"),   driverController.updateLocation
app.post '/driver/taxi/update',     authorizationController.restrict_to("driver"),   driverController.updateState
app.get  '/driver/refresh',         authorizationController.restrict_to("driver"),   driverController.refresh

######################################################
# passenger routes
######################################################
app.post '/passenger/signup',           passengerController.signup
app.post '/passenger/signin',           passengerController.signin
app.post '/passenger/signout',          authorizationController.restrict_to("passenger"),   passengerController.signout
app.post '/passenger/location/update',  authorizationController.restrict_to("passenger"),   passengerController.updateLocation
app.get  '/passenger/refresh',          authorizationController.restrict_to("passenger"),   passengerController.refresh

######################################################
# taxi call routes
######################################################
app.get  '/taxi/near',                authorizationController.restrict_to("passenger"),    taxiCallController.getNearTaxis
app.post '/service/create',           authorizationController.restrict_to("passenger"),    taxiCallController.create
app.post '/service/reply',            authorizationController.restrict_to("driver"),       taxiCallController.reply
app.post '/service/cancel',           authorizationController.restrict_to("passenger"),    taxiCallController.cancel
app.post '/service/complete',         authorizationController.restrict_to("driver"),       taxiCallController.complete
app.post '/service/evaluate',         authorizationController.restrict_to(["passenger", "driver"]),         taxiCallController.evaluate
app.get  '/service/history',          authorizationController.restrict_to(["passenger", "driver"]),         taxiCallController.history
app.get  '/service/evaluations',      authorizationController.restrict_to(["passenger", "driver"]),         taxiCallController.getEvaluations
app.get  '/service/user/evaluations', authorizationController.restrict_to(["passenger", "driver"]),         taxiCallController.getUserEvaluations

######################################################
# location routes
######################################################
app.post '/location/create',          authorizationController.restrict_to("user"),       locationController.create
