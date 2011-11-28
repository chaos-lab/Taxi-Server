# User collection

mongodb = require('mongodb')

# driver schema
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: {latitude: 23.2343, longitude: 126.343}, role: 1, created_at: Date, updated_at: Date, car_number: "xxxx" }

# passenger
# { phone_number: "13814171931", password: "123456", nickname: "liufy", state: 1, messages:[], location: {latitude: 23.2343, longitude: 126.343}, role: 2, created_at: Date, updated_at: Date }

module.exports = User =
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'users')

    this.collection.ensureIndex {phone_number: 1}, {unique: true}, (err, name)->
      console.log("Index #{name} created.")
    this.collection.ensureIndex {car_number: 1}, {sparse: true}, (err, name)->
      console.log("Index #{name} created.")
    this.collection.ensureIndex {location: "2d"}, (err, name)->
      console.log("Index #{name} created.")
    this.collection.ensureIndex {role: 1}, (err, name)->
      console.log("Index #{name} created.")

  create: (json) ->
    json.created_at = new Date
    json.updated_at = new Date
    this.collection.insert(json)

  update: (phone, json) ->

  find: (query, fn) ->

  send: (phone, message) ->

