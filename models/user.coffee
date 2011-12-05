# User collection

mongodb = require('mongodb')
Message = require('./message')

# driver schema
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: {latitude: 23.2343, longitude: 126.343}, role: 1, created_at: Date, updated_at: Date, last_active_at: Date, car_number: "xxxx", taxi_state: 1 }

# passenger
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: {latitude: 23.2343, longitude: 126.343}, role: 2, created_at: Date, updated_at: Date, last_active_at: Date }

module.exports = User =
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'users')

    this.collection.ensureIndex {phone_number: 1}, {unique: true}, (err, name)->
    this.collection.ensureIndex {car_number: 1}, {sparse: true}, (err, name)->
    this.collection.ensureIndex {location: "2d"}, (err, name)->
    this.collection.ensureIndex {role: 1}, (err, name)->

  create: (json, fn) ->
    json.created_at = new Date
    json.updated_at = new Date

    this.collection.insert json, (err, docs) ->
      doc = if docs then docs[0] else null
      fn(err, doc) if fn

  send: (phone, message) ->
    this.collection.findOne { phone_number: phone }, {}, (err, doc) =>
      return unless doc

      this.collection.update { _id: doc._id }, { $push: {messages: message} }

  getMessages: (phone, fn)
    Message.collection.find {receiver: phone}, (err, cursor) ->
      cursor.toArray (err, docs) ->
        messages = []
        for doc in docs
          messages.push(doc)
          Message.collection.remove(doc)

        fn(messages) if fn

