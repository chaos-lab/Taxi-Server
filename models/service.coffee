# Service collection
mongodb = require('mongodb')

# service schema
# { id: 4534, state: 1, driver: "13313145", passenger: "13954355435", origin:{ longitude: 23.454, latitude:132.54554 }, destination:{ longitude: 23.454, latitude:132.54554 }, created_at: Date, updated_at: Date }

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

