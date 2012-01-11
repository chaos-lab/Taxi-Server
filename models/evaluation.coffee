# evaluations collection
mongodb = require('mongodb')

# evaluation schema
# { service_id: 34, evaluator: "liufy", target: "liuq", role: "passenger"|"driver", score: 6, comment: "This is good", created_at: new Date }

module.exports = Evaluation =
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'evaluations')
    this.collection.ensureIndex {target: 1}, (err, name)->
    this.collection.ensureIndex {evaluator: 1}, (err, name)->
    this.collection.ensureIndex {service_id: 1}, (err, name)->
    this.collection.ensureIndex {created_at: 1}, (err, name)->

  create: (json, fn) ->
    json.created_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn
