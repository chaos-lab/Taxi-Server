winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

scanUserState = ->
  winston.info("scan user state every 10s")
  User.collection.update { last_active_at:{$lt: new Date(new Date().valueOf() - 10000)}, state: 2}, {$set: {state: 0}}

scanServiceState = ->
  winston.info("scan user state every 100s")
  Service.collection.find  { created_at:{$lt: new Date(new Date().valueOf() - 1800000)}, state: 2 }

setInterval(scanUserState, 10000)
setInterval(scanServiceState, 100000)


