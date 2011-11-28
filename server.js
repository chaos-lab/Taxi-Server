require('coffee-script')

global.config = require('./config')
webapp = require('./webserver')
webapp.start()

