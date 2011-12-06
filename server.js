require('coffee-script')

var env = process.env.NODE_ENV || 'development'
process.env.NODE_ENV = env
global.config = require('./init/' + env)

var webapp = module.exports = require('./webserver')
webapp.setupDB(function(db) {
  if (!module.parent) webapp.start()
})

