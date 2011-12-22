require('coffee-script')

var env = process.env.NODE_ENV || 'development'
process.env.NODE_ENV = env
global.config = require('./init/' + env)

var webapp = module.exports = require('./webserver')
if (!module.parent) webapp.start()

