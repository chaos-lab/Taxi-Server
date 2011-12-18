process.env.NODE_ENV = 'test'
global.config = require('../init/test')

mongodb = require('mongodb')

module.exports = helper =
  cleanDB: (db, fn)->
    users = new mongodb.Collection(db, 'users')
    services = new mongodb.Collection(db, 'services')
    messages = new mongodb.Collection(db, 'messages')
    evaluations = new mongodb.Collection(db, 'evaluations')
    counters = new mongodb.Collection(db, 'counters')
    users.drop ->
      services.drop ->
        messages.drop ->
          evaluations.drop ->
            counters.drop ->
              fn()

  createUser: (db, json, fn) ->
    users = new mongodb.Collection(db, 'users')
    users.insert json, (err, docs)->
      fn()

  createService: (db, json, fn) ->
    services = new mongodb.Collection(db, 'users')
    services.insert json, (err, docs)->
      fn()

  signin_passenger: (browser, json, fn)->
    browser.post '/passenger/signin', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)

  signin_driver: (browser, json, fn)->
    browser.post '/driver/signin', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)

  signout_passenger: (browser, fn)->
    browser.post '/passenger/signout', (res, $) ->
      fn(res, $)

  signout_driver: (browser, fn)->
    browser.post '/driver/signout', (res, $) ->
      fn(res, $)

  update_driver_location: (browser, json, fn)->
    browser.post '/driver/location/update', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)

  update_passenger_location: (browser, json, fn)->
    browser.post '/passenger/location/update', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)

