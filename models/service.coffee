# Service collection
mongodb = require('mongodb')

# service schema
# { id: 4534, state: 1, driver: "13313145", passenger: "13954355435", origin:{ longitude: 23.454, latitude:132.54554 }, destination:{ longitude: 23.454, latitude:132.54554 }, created_at: Date, updated_at: Date }

module.exports = Service =
  setup: (db) ->
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

  update: (phone, json) ->

  find: (query, fn) ->

