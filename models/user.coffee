# User collection

mongodb = require('mongodb')
Message = require('./message')
Service = require('./service')
Evaluation = require('./evaluation')

# driver schema
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: [23.2343, 126.343], role: 1, created_at: Date, updated_at: Date, last_active_at: Date, car_number: "xxxx", taxi_state: 1 }

# passenger
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: [23.2343, 126.343], role: 2, created_at: Date, updated_at: Date, last_active_at: Date }

module.exports = User =
  ##
  # setup db access
  ##
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'users')

    this.collection.ensureIndex {phone_number: 1}, {unique: true}, (err, name)->
    this.collection.ensureIndex {car_number: 1}, {sparse: true}, (err, name)->
    this.collection.ensureIndex {location: "2d"}, (err, name)->
    this.collection.ensureIndex {role: 1}, (err, name)->

  ##
  # create a new user
  ##
  create: (json, fn) ->
    json.created_at = new Date
    json.updated_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn

  ##
  # get user statistics
  ##
  stats: (user, fn) ->
    query = if user.role == 1 then {passenger: user.phone_number, state: 3} else {driver: user.phone_number, state: 3}
    Service.collection.find(query).count (err, count)->
      map = ->
        if user.role == 1
          emit this.passenger, {score: this.score, count: 1}
        else
          emit this.driver, {score: this.score, count: 1}

      reduce = (k, vals)->
        result = {score: 0, count: 1}
        for val in vals
          result.score += val.score
          result.count += val.count
        return result

      Service.collection.mapReduce map, reduce, {out : {inline: 1}}, (err, results)->
        average = if results[0].value.count > 0 then results[0].value.score / results[0].value.count else 0
        fn {average_score: average, total_service_count: count} if fn

  ##
  # get user messages
  ##
  getMessages: (phone, fn)->
    Message.collection.find({receiver: phone}).toArray (err, docs) ->
      messages = []
      for doc in docs
        messages.push(doc)
        Message.collection.remove(doc)

      fn(messages) if fn

