# User collection

mongodb = require('mongodb')
Message = require('./message')
Service = require('./service')
Evaluation = require('./evaluation')

# driver schema
# { phone_number: "13814171931", password: "123456", name: "liufy", state: 1, messages:[], location: [23.2343, 126.343], role: 1, created_at: Date, updated_at: Date, last_active_at: Date, car_number: "xxxx", taxi_state: 1, stats: {average_score: 3.6, service_count: 67, evaluation_count: 54 } }

# passenger
# { phone_number: "13814171931", password: "123456", name: "liufy", state: 1, messages:[], location: [23.2343, 126.343], role: 2, created_at: Date, updated_at: Date, last_active_at: Date, stats: {average_score: 3.6, service_count: 67, evaluation_count: 54 } }

module.exports = User =
  ##
  # setup db access
  ##
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'users')

    this.collection.ensureIndex {phone_number: 1}, {unique: true}, (err, name)->
    this.collection.ensureIndex {name: 1}, {unique: true}, (err, name)->
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
  # update user statistics
  ##
  updateStats: (name, fn) ->
    map = -> emit this.target, {score: this.score, count: 1}

    reduce = (k, vals)->
      result = {score: 0, count: 0}
      for val in vals
        result.score += val.score
        result.count += val.count
      return result

    Evaluation.collection.mapReduce map, reduce, {out: {inline: 1}, query: {target: name}, limit: 1000}, (err, results) =>
      count = results[0].value.count || 0
      average = if results[0].value.count > 0 then results[0].value.score / results[0].value.count else 0
      this.collection.update {name: name}, {$set: {"stats.average_score": average, "stats.evaluation_count":count}}
      fn {average_score: average, evaluation_count: count} if fn

  ##
  # get user messages
  ##
  getMessages: (name, fn)->
    Message.collection.find({receiver: name}).toArray (err, docs) ->
      messages = []
      for doc in docs
        messages.push(doc)
        Message.collection.remove(doc)

      fn(messages) if fn

