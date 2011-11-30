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

