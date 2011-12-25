# taxi call controller

winston = require('winston')

User = require('../models/user')
Service = require('../models/service')
Message = require('../models/message')
Evaluation = require('../models/evaluation')

class TaxiCallController
  constructor: ->

  ##
  # return taxis near current user.
  ##
  getNearTaxis: (req, res) ->
    taxis = []

    User.collection.find({ role:2, state:{$gte: 1}, taxi_state:1, location:{$exists: true} }).toArray (err, docs)->
      if err
        winston.warn("Service getNearTaxis - database error")
        return res.json { status: 3, message: "database error" }


      for doc in docs
        if doc.location
          # set default stats
          doc.stats = {average_score: 0, service_count: 0, evaluation_count: 0} unless doc.stats
          taxis.push
            phone_number: doc.phone_number
            nickname: doc.nickname
            car_number: doc.car_number
            longitude: doc.location[0]
            latitude: doc.location[1]
            stats: doc.stats

      res.json { status: 0, taxis: taxis }

  ##
  # create taxi call request
  ##
  create: (req, res) ->
    unless req.json_data && req.json_data.key && req.json_data.driver && (!req.json_data.origin || (req.json_data.origin.longitude && req.json_data.origin.latitude)) && (!req.json_data.destination || (req.json_data.destination.longitude && req.json_data.destination.latitude))
      console.dir(req.json_data)
      winston.warn("Service create - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    User.collection.findOne {phone_number: req.json_data.driver}, (err, doc) ->
      if !doc || doc.state == 0 || doc.taxi_state != 1
        winston.warn("Service create - driver #{req.json_data.driver} can't accept taxi call for now", doc)
        return res.json { status: 101, message: "driver can't accept taxi call for now" }

      # only one active service is allowed for a user at the same time
      Service.collection.findOne {passenger: req.current_user.phone_number, $or:[{state:1}, {state:2}]}, (err, doc) ->
        # cancel existing services
        if doc
          Service.collection.update({_id: doc._id}, {$set: {state: -2}})
          # send cancel message to driver
          message =
            receiver: doc.driver
            type: "call-taxi-cancel"
            id: doc._id
            timestamp: new Date().valueOf()
          Message.collection.update({receiver: message.receiver, id:message.id, type: message.type}, message, {upsert: true})

        origin = if req.json_data.origin then [req.json_data.origin.longitude, req.json_data.origin.latitude, req.json_data.origin.name] else req.current_user.location
        destination = if req.json_data.destination then [req.json_data.destination.longitude, req.json_data.destination.latitude, req.json_data.destination.name] else null
        # create new service
        Service.uniqueID (id)->
          data =
            driver: req.json_data.driver
            passenger: req.current_user.phone_number
            state: 1
            origin: origin
            destination: destination
            key: req.json_data.key
            _id: id
          Service.create data

          # send call-taxi message to driver
          message =
            receiver: req.json_data.driver
            type: "call-taxi"
            passenger:
              phone_number: req.current_user.phone_number
              nickname:req.current_user.nickname
            origin:
              longitude: origin[0]
              latitude: origin[1]
              name: origin[2]
            id: id
            timestamp: new Date().valueOf()
          message.destination = {longitude: destination[0], latitude: destination[1], name: destination[2]} if destination
          Message.collection.update({receiver: message.receiver, passenger:message.passenger, type: message.type}, message, {upsert: true})

          res.json { status: 0, id: id }

  ##
  # driver reply to a taxi call
  ##
  reply: (req, res) ->
    unless req.json_data && req.json_data.id
      winston.warn("Service reply - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # service doesn't exist, already cancelled, etc
      unless doc && doc.state == 1
        winston.warn("Service reply - service can't be replied", doc)
        return res.json { status: 101, message: "service can't be replied" }

      state = if req.json_data.accept then 2 else -1
      Service.collection.update({_id: req.json_data.id}, {$set: {state: state, updated_at: new Date()}})
      # set taxi state to running
      User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: 2}}) if req.json_data.accept

      message =
        receiver: doc.passenger
        type: "call-taxi-reply"
        accept: req.json_data.accept
        id: doc._id
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      res.json { status: 0 }

  ##
  # passenger cancel a taxi call
  ##
  cancel: (req, res) ->
    unless req.json_data && (req.json_data.id || req.json_data.key)
      winston.warn("Service cancel - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    query = if req.json_data.id then {_id: req.json_data.id} else {key: req.json_data.key, passenger: req.current_user.phone_number}

    Service.collection.findOne query, (err, doc) ->
      # can't cancel completed service or rejected service
      if !doc || (doc.state != 2 && doc.state != 1)
        winston.warn("Service reply - service can't be cancelled", doc)
        return res.json { status: 101, message: "service can't be cancelled" }

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

      res.json { status: 0 }

  ##
  # driver notify the completion of a service
  ##
  complete: (req, res) ->
    unless req.json_data && req.json_data.id
      winston.warn("Service complete - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Service.collection.findOne {_id: req.json_data.id}, (err, doc) ->
      # can only complete accepted service
      unless doc && doc.state == 2
        winston.warn("Service complete - service can't be completed", doc)
        return res.json { status: 101, message: "only accepted service can be completed" }

      Service.collection.update({_id: doc._id}, {$set: {state: 3, updated_at: new Date()}})
      # set taxi state to idle
      User.collection.update({_id: req.current_user._id}, {$set: {taxi_state: 1}, $inc:{"stats.service_count": 1}})
      User.collection.update({phone_number: doc.passenger}, {$inc:{"stats.service_count": 1}})

      message =
        receiver: doc.passenger
        type: "call-taxi-complete"
        id: doc._id
        key: doc.key
        timestamp: new Date().valueOf()
      Message.collection.update({receiver: message.receiver, key:message.key, type: message.type}, message, {upsert: true})

      res.json { status: 0 }

  ##
  # evaluate a service
  ##
  evaluate: (req, res) ->
    unless req.json_data && req.json_data.id && req.json_data.score
      winston.warn("Service evaluate - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Service.collection.findOne {_id: req.json_data.id}, (err, service) ->
      # can only evaluate completed service
      unless service.state == 3
        winston.warn("Service evaluate - service can't be evaluated", service)
        return res.json { status: 101, message: "only completed service can be evaluated" }

      unless service.driver == req.current_user.phone_number || service.passenger == req.current_user.phone_number
        winston.warn("Service evaluate - you can't evaluate this service.", service)
        return res.json { status: 102, message: "you can't evaluate this service" }

      Evaluation.collection.findOne {service_id: req.json_data.id, "evaluator": req.current_user.phone_number}, (err, doc) ->
        if doc
          winston.warn("Service evaluate - you have evaluated this service", doc)
          return res.json { status: 103, message: "you have evaluated this service" }

        target = if req.current_user.role == 1 then service.driver else service.passenger
        # create evaluation
        evaluation =
          service_id: service._id
          evaluator: req.current_user.phone_number
          target: target
          role: req.current_user.role
          score: req.json_data.score
          comment: req.json_data.comment
        Evaluation.create evaluation, (err, doc)->
          User.updateStats(target)

        res.json { status: 0 }

  ##
  # get evaluations of specified services
  ##
  getEvaluations: (req, res) ->
    unless req.json_data && req.json_data.ids
      winston.warn("Service getEvaluations - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    Evaluation.collection.find({service_id:{$in: req.json_data.ids}}).toArray (err, docs)->
      if err
        winston.warn("Service getEvaluations - database error")
        return res.json { status: 3, message: "database error" }

      result =  {status: 0}
      for evaluation in docs
        result[evaluation.service_id] = result[evaluation.service_id] || {}
        if evaluation.role == 1
          result[evaluation.service_id]["passenger_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}
        else
          result[evaluation.service_id]["driver_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}

      res.json result

  ##
  # get evaluations of a user
  ##
  getUserEvaluations: (req, res) ->
    unless req.json_data && req.json_data.phone_number && req.json_data.end_time
      winston.warn("Service getEvaluations - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    # set default count to 20
    req.json_data.count = req.json_data.count || 20

    User.collection.findOne {phone_number: req.json_data.phone_number}, (err, user) ->
      if err
        winston.warn("Service getUserEvaluations - database error")
        return res.json { status: 3, message: "database error" }

      if !user
        winston.warn("driver signin - database error")
        return res.json { status: 101, message: "database error" }

      Evaluation.collection.find({created_at: {$lte: new Date(req.json_data.end_time)}, "target":user.phone_number}, {limit: req.json_data.count, sort:[['created_at', 'desc']]}).toArray (err, docs)->
        if err
          winston.warn("Service getUserEvaluations - database error")
          return res.json { status: 3, message: "database error" }

        evals = []
        keys = []
        for evaluation in docs
          keys.push evaluation.evaluator
          evals.push
            score: evaluation.score
            comment: evaluation.comment
            created_at: evaluation.created_at.valueOf()
            evaluator: evaluation.evaluator

        # set evaluator nickname. mongodb doesn't support join
        User.collection.find({phone_number: {$in: keys}}).toArray (err, docs)->
          if err
            winston.warn("Service getUserEvaluations - database error")
            return res.json { status: 3, message: "database error" }

          evaluators = {}
          evaluators[evaluator.phone_number] = evaluator for evaluator in docs

          # set evaluator to nickname
          evaluation.evaluator = evaluators[evaluation.evaluator].nickname for evaluation in evals

          return res.json { status: 0, evaluations: evals}

  ##
  # get history of services related to current user
  ##
  history: (req, res) ->
    unless req.json_data && req.json_data.end_time
      winston.warn("Service history - incorrect data format", req.json_data)
      return res.json { status: 2, message: "incorrect data format" }

    # set default params
    req.json_data.count = req.json_data.count || 10
    req.json_data.start_time = req.json_data.start_time || new Date(2011, 11, 11)

    driver_query = {state: {$in: [-3, -2, -1, 3]}, driver: req.current_user.phone_number, created_at:{$lte: new Date(req.json_data.end_time), $gte: new Date(req.json_data.start_time)}}
    passenger_query = {state: {$in: [-3, -2, -1, 3]}, passenger: req.current_user.phone_number, created_at:{$lte: new Date(req.json_data.end_time), $gte: new Date(req.json_data.start_time)}}
    query = if req.current_user.role == 1 then passenger_query else driver_query

    Service.collection.find(query, {limit: req.json_data.count, sort:[['created_at', 'desc']]}).toArray (err, services)->
      if err
        winston.warn("Service history - database error")
        return res.json { status: 3, message: "database error" }

      service_map = {}
      service_keys = []
      user_keys = []
      for service in services
        service_map[service._id] = service
        service_keys.push(service._id)
        if req.current_user.role == 1
          user_keys.push(service.driver)
        else
          user_keys.push(service.passenger)

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
      User.collection.find({phone_number: {$in: user_keys}}).toArray (err, users)->
        if err
          winston.warn("Service getUserEvaluations - database error")
          return res.json { status: 3, message: "database error" }

        user_map = {}
        user_map[user.phone_number] = user for user in users

        # set detailed user info
        for service in services
          if req.current_user.role == 1
            delete service.passenger
            stats = if user_map[service.driver].stats then user_map[service.driver].stats else {average_score: 0, service_count: 0, evaluation_count: 0}
            service.driver =
              phone_number: service.driver
              nickname: user_map[service.driver].nickname
              car_number: user_map[service.driver].car_number
              stats: stats
          else
            delete service.driver
            stats = if user_map[service.passenger].stats then user_map[service.passenger].stats else {average_score: 0, service_count: 0, evaluation_count: 0}
            service.passenger =
              phone_number: service.passenger
              nickname: user_map[service.passenger].nickname
              stats: stats

        # load evaluations
        Evaluation.collection.find({service_id:{$in: service_keys}}).toArray (err, evaluations)->
          if err
            winston.warn("Service getEvaluations - database error")
            return res.json { status: 3, message: "database error" }

          # set evaluations
          for evaluation in evaluations
            if evaluation.role == 1
              service_map[evaluation.service_id]["passenger_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}
            else
              service_map[evaluation.service_id]["driver_evaluation"] = {score: evaluation.score, comment: evaluation.comment, created_at: evaluation.created_at.valueOf()}

          res.json { status: 0, services: services }

module.exports = TaxiCallController
