# evaluations collection
mongodb = require('mongodb')

# evaluation schema
# { service_id: 34, evaluator: "liufy", target: "liuq", role: "passenger"|"driver", score: 6, comment: "This is good", created_at: new Date }

module.exports = Evaluation =
  ##
  # setup db & index
  ##
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'evaluations')
    this.collection.ensureIndex {target: 1}, (err, name)->
    this.collection.ensureIndex {evaluator: 1}, (err, name)->
    this.collection.ensureIndex {service_id: 1}, (err, name)->
    this.collection.ensureIndex {created_at: 1}, (err, name)->

  ##
  # create an evaluation
  ##
  create: (json, fn) ->
    Service.collection.findOne {_id: json.id}, (err, service) =>
      unless service
        logger.warning("Service evaluate - service not found %", json.id)
        fn { status: 104, message: "service not found" } if fn
        return

      # can only evaluate completed service
      unless service.state == 3
        logger.warning("Service evaluate - service can't be evaluated %s", service)
        fn { status: 101, message: "only completed service can be evaluated" } if fn
        return

      unless service.driver == json.evaluator || service.passenger == json.evaluator
        logger.warning("Service evaluate - you can't evaluate this service. %s", service)
        fn { status: 102, message: "you can't evaluate this service" } if fn
        return

      Evaluation.collection.findOne {service_id: json.id, "evaluator": json.evaluator}, (err, doc) =>
        if doc
          logger.warning("Service evaluate - you have evaluated this service %s", doc)
          fn { status: 103, message: "you have evaluated this service" } if fn
          return

        target = if json.evaluator == service.passenger then service.driver else service.passenger
        # create evaluation
        json =
          service_id: service._id
          evaluator: json.evaluator
          target: target
          role: json.role
          score: json.score
          comment: json.comment
          created_at: new Date
        this.collection.insert json, (err, docs) ->
          User.updateStats(target)

        fn { status: 0 } if fn

  ##
  # search evaluations
  ##
  search: (query, options, fn)->
    Evaluation.collection.find(query, options).toArray (err, docs)->
      if err
        logger.error("Service getUserEvaluations - database error")
        fn { status: 3, message: "database error" } if fn
        return

      evals = []
      keys = []
      for evaluation in docs
        keys.push evaluation.evaluator
        evals.push
          score: evaluation.score
          comment: evaluation.comment
          created_at: evaluation.created_at.valueOf()
          evaluator: evaluation.evaluator

      # set evaluator name. mongodb doesn't support join
      User.collection.find({name: {$in: keys}}).toArray (err, docs)->
        if err
          logger.error("Service getUserEvaluations - database error")
          fn { status: 3, message: "database error" } if fn
          return

        evaluators = {}
        evaluators[evaluator.name] = evaluator for evaluator in docs

        # set evaluator to name
        evaluation.evaluator = evaluators[evaluation.evaluator].name for evaluation in evals

        fn { status: 0, evaluations: evals} if fn

