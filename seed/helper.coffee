process.env.NODE_ENV = 'test'
global.config = require('../init/production')

mongodb = require('mongodb')

module.exports = helper =
  createUser: (db, json, fn) ->
    users = new mongodb.Collection(db, 'users')
    users.update {$or:[{phone_number: json.phone_number}, {name: json.name}]}, json, {upsert: true}, (err, doc)->
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

