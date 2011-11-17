require('coffee-script')

global.config = require('./config')
webapp = require('./lib/webserver')
webapp.start()

