# evaluations collection
mongodb = require('mongodb')

# evaluation schema
# { service_id: 34, driver: "1592342334", passenger: "1392342432", role: 1|2, score: 6, comment: "This is good", created_at: new Date }

module.exports = Evaluation =
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'evaluations')
    this.collection.ensureIndex {driver: 1}, (err, name)->
    this.collection.ensureIndex {passenger: 1}, (err, name)->
    this.collection.ensureIndex {service_id: 1}, (err, name)->
    this.collection.ensureIndex {created_at: 1}, (err, name)->

  create: (json, fn) ->
    json.created_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn
