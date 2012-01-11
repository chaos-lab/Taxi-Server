# Service collection
mongodb = require('mongodb')

# service schema
# { id: 4534, state: 1, driver: "liuq", passenger: "souriki", origin:[23.454, 132.54554, "location1"], destination:[23.454, 132.54554, "location2"], created_at: Date, updated_at: Date }

module.exports = Service =
  setup: (db) ->
    this.counters = new mongodb.Collection(db, 'counters')
    this.collection = new mongodb.Collection(db, 'services')
    this.collection.ensureIndex {driver: 1}, (err, name)->
    this.collection.ensureIndex {passenger: 1}, (err, name)->
    this.collection.ensureIndex {key: 1}, (err, name)->

  create: (json, fn) ->
    json.created_at = new Date
    json.updated_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn

  uniqueID: (fn) ->
    query = { _id: 'services' }
    sort = [['_id','asc']]
    update = { $inc: { next: 1 } }
    options = { 'new': true, upsert: true }

    this.counters.findAndModify query, sort, update, options, (err, doc)->
      fn(doc.next)

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
