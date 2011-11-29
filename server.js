require('coffee-script')

process.env.NODE_ENV = process.env.NODE_ENV || 'development'

global.config = require('./init/' + process.env.NODE_ENV)
webapp = require('./webserver')
webapp.start()

