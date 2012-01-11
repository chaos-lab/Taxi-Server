# Service collection
mongodb = require('mongodb')

# service schema
# { id: 4534, state: 1, driver: "liuq", passenger: "souriki", origin:[23.454, 132.54554, "location1"], destination:[23.454, 132.54554, "location2"], created_at: Date, updated_at: Date }

module.exports = Service =
  ##
  # setup db & index
  ##
  setup: (db) ->
    this.counters = new mongodb.Collection(db, 'counters')
    this.collection = new mongodb.Collection(db, 'services')
    this.collection.ensureIndex {driver: 1}, (err, name)->
    this.collection.ensureIndex {passenger: 1}, (err, name)->
    this.collection.ensureIndex {key: 1}, (err, name)->

  ##
  # create instance & store in db
  ##
  create: (json, fn) ->
    json.created_at = new Date
    json.updated_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn

  ##
  # generate unique id
  ##
  uniqueID: (fn) ->
    query = { _id: 'services' }
    sort = [['_id','asc']]
    update = { $inc: { next: 1 } }
    options = { 'new': true, upsert: true }

    this.counters.findAndModify query, sort, update, options, (err, doc)->
      fn(doc.next)

  ##
  # reply a taxi call
  ##
  reply: (json, fn)->
    Service.collection.findOne {_id: json.id}, (err, doc) ->
      # service doesn't exist, already cancelled, etc
      unless doc && doc.state == 1
        logger.warning("Service reply - service can't be replied %s", doc)
        fn { status: 101, message: "service can't be replied" } if fn
        return

      if doc.driver!= json.actor.name
        logger.warning("Service reply- can't reply other's service %s %s", json.actor, doc)
        fn { status: 102, message: "can't reply other's service" } if fn
        return

      state = if json.accept then 2 else -1
      Service.collection.update({_id: json.id}, {$set: {state: state, updated_at: new Date()}})
      # set taxi state to running
      User.collection.update({name: json.actor.name}, {$set: {taxi_state: 2}}) if json.accept

      message =
        receiver: doc.passenger
        type: "call-taxi-reply"
        accept: json.accept
        id: doc._id
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      fn { status: 0 } if fn

  ##
  # cancel a taxi call
  ##
  cancel: (query, actor, fn)->
    Service.collection.findOne query, (err, doc) ->
      # can't cancel completed service or rejected service
      if !doc || (doc.state != 2 && doc.state != 1)
        logger.warning("Service cancel - service can't be cancelled %s", doc)
        fn { status: 101, message: "service can't be cancelled" } if fn
        return

      if doc.passenger != actor.name
        logger.warning("Service cancel - can't cancel other's service %s %s", actor, doc)
        fn { status: 102, message: "can't cancel other's service" } if fn
        return

      # update service state
      Service.collection.update({_id: doc._id}, {$set: {state: -2, updated_at: new Date()}})
      # remove call-taxi message if it's not sent
      Message.collection.remove({receiver: doc.driver, id: doc._id, type: "call-taxi"})

      message =
        receiver: doc.driver
        type: "call-taxi-cancel"
        id: doc._id
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

      fn { status: 0 } if fn

  ##
  # complete a taxi call
  ##
  complete: (json, fn)->
    Service.collection.findOne {_id: json.id}, (err, doc) ->
      # can only complete accepted service
      unless doc && doc.state == 2
        logger.warning("Service complete - service can't be completed %s", doc)
        fn { status: 101, message: "only accepted service can be completed" } if fn
        return

      if doc.driver != json.actor.name
        logger.warning("Service complete - can't complete other's service %s %s", json.actor, doc)
        fn { status: 102, message: "can't complete other's service" } if fn
        return

      Service.collection.update({_id: doc._id}, {$set: {state: 3, updated_at: new Date()}})
      # set taxi state to idle
      User.collection.update({name: doc.driver}, {$set: {taxi_state: 1}, $inc:{"stats.service_count": 1}})
      User.collection.update({name: doc.passenger}, {$inc:{"stats.service_count": 1}})

      message =
        receiver: doc.passenger
        type: "call-taxi-complete"
        id: doc._id
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      fn { status: 0 } if fn


  ##
  # search service
  ##
  search: (query, options, fn)->
    Service.collection.find(query, options).toArray (err, services)->
      if err
        logger.warning("Service history - database error")
        fn { status: 3, message: "database error" } if fn
        return

      service_map = {}
      service_keys = []
      user_keys = []
      for service in services
        service_map[service._id] = service
        service_keys.push(service._id)
        user_keys.push(service.driver) unless _.include(user_keys, service.driver)
        user_keys.push(service.passenger) unless _.include(user_keys, service.passenger)

        service.id = service._id
        delete service._id

        service.created_at = service.created_at.valueOf()
        service.updated_at = service.updated_at.valueOf()

        service.origin =
          longitude: service.origin[0]
          latitude: service.origin[1]
          name: service.origin[2]

        if service.destination
          service.destination =
            longitude: service.destination[0]
            latitude: service.destination[1]
            name: service.destination[2]

      # load details user info
      User.collection.find({name: {$in: user_keys}}).toArray (err, users)->
        if err
          logger.error("Service getUserEvaluations - database error")
          fn { status: 3, message: "database error" } if fn
          return

        user_map = {}
        user_map[user.name] = user for user in users

        # set detailed user info
        for service in services
          stats = if user_map[service.driver].stats then user_map[service.driver].stats else {average_score: 0, service_count: 0, evaluation_count: 0}
          service.driver =
            phone_number: user_map[service.driver].phone_number
            name: service.driver
            car_number: user_map[service.driver].car_number
            stats: stats

          stats = if user_map[service.passenger].stats then user_map[service.passenger].stats else {average_score: 0, service_count: 0, evaluation_count: 0}
          service.passenger =
            phone_number: user_map[service.passenger].phone_number
            name: service.passenger
            stats: stats

        # load evaluations
        Evaluation.collection.find({service_id:{$in: service_keys}}).toArray (err, evaluations)->
          if err
            logger.error("Service getEvaluations - database error")
            fn { status: 3, message: "database error" } if fn
            return

          # set evaluations
          for evaluation in evaluations
            if evaluation.role == "passenger"
              service_map[evaluation.service_id]["passenger_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}
            else
              service_map[evaluation.service_id]["driver_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}

          fn { status: 0, services: services } if fn
