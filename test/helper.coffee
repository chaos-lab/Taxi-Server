process.env.NODE_ENV = 'test'
global.config = require('../init/test')

mongodb = require('mongodb')

module.exports = helper =
  cleanDB: (db, fn)->
    users = new mongodb.Collection(db, 'users')
    services = new mongodb.Collection(db, 'services')
    users.remove {}, {}, (err, count) ->
      services.remove {}, {}, (err, count) ->
        fn()
    return

  createUser: (db, json, fn) ->
    users = new mongodb.Collection(db, 'users')
    users.insert json, (err, docs)->
      fn()
    return

  createService: (db, json, fn) ->
    services = new mongodb.Collection(db, 'users')
    services.insert json, (err, docs)->
      fn()
    return

  signin_passenger: (browser, json, fn)->
    browser.post '/passenger/signin', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)
    return

  signin_driver: (browser, json, fn)->
    browser.post '/driver/signin', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)
    return

  signout_passenger: (browser, fn)->
    browser.post '/passenger/signout', (res, $) ->
      fn(res, $)
    return

  signout_driver: (browser, fn)->
    browser.post '/driver/signout', (res, $) ->
      fn(res, $)
    return

  update_driver_location: (browser, json, fn)->
    browser.post '/driver/location/update', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)
    return

  update_passenger_location: (browser, json, fn)->
    browser.post '/passenger/location/update', { body: 'json_data=' + JSON.stringify(json)}, (res, $) ->
      fn(res, $)
    return

