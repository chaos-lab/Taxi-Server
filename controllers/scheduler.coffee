winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')

scanUserState = ->
  winston.info("scan user state every 10s")
  User.collection.update { last_active_at:{$lt: new Date(new Date().valueOf() - 10000)}, state: 2}, {$set: {state: 0}}

scanServiceState = ->
  winston.info("scan user state every 100s")

  # if service is accepted for more than one hour, cancel it
  Service.collection.find  { created_at:{$lt: new Date(new Date().valueOf() - 3600000)}, state: 2 }, (err, cursor) ->
    cursor.toArray (err, docs) ->
      for doc in docs
        winston.info("scheduler - service timeout:", doc)
        Service.collection.update doc, { $set: { state: -3 } }
        # send timeout message to driver & passenger
        message =
          receiver: doc.driver
          type: "call-taxi-timeout"
          id: doc._id
          timestamp: new Date().valueOf()
        Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})
        message.receiver = doc.passenger
        Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

  # if service is initiated for more than half an hour, cancel it
  Service.collection.find  { created_at:{$lt: new Date(new Date().valueOf() - 1800000)}, state: 1 }, (err, cursor) ->
    cursor.toArray (err, docs) ->
      for doc in docs
        winston.info("scheduler - service timeout:", doc)
        Service.collection.update doc, { $set: { state: -3 } }
        # send timeout message to driver & passenger
        message =
          receiver: doc.passenger
          type: "call-taxi-timeout"
          id: doc._id
          timestamp: new Date().valueOf()
        Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

setInterval(scanUserState, 10000)
setInterval(scanServiceState, 100000)

