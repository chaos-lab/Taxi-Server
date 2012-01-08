User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

scanUserState = ->
  logger.info("scan user state every 10s")
  User.collection.update { last_active_at:{$lt: new Date(new Date().valueOf() - 10000)}, state: 2}, {$set: {state: 0}}

scanServiceState = ->
  logger.info("scan service state every 100s")

  # if service is accepted for more than one hour, cancel it
  Service.collection.find({ created_at:{$lt: new Date(new Date().valueOf() - 3600000)}, state: 2 }).toArray (err, docs) ->
    if err
      logger.error("scheduler scanServiceState - database error")
      return

    for doc in docs
      logger.info("scheduler - service timeout: %s", doc)
      Service.collection.update doc, { $set: { state: -3 } }

  # if service is initiated for more than half an hour, cancel it
  Service.collection.find({ created_at:{$lt: new Date(new Date().valueOf() - 1800000)}, state: 1 }).toArray (err, docs) ->
    if err
      logger.warning("scheduler scanServiceState - database error")
      return

    for doc in docs
      logger.info("scheduler - service timeout: %s", doc)
      Service.collection.update doc, { $set: { state: -3 } }

setInterval(scanUserState, 10000)
setInterval(scanServiceState, 100000)

