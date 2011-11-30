require('coffee-script')

# app init
process.env.NODE_ENV = 'test'
global.config = require('../init/test')
app = require('../webserver')

tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
browser = tobi.createBrowser(app)

batch1 =
  "passenger":
    topic: ->
      # app.setupDB(this.callback) doesn't work!!!
      self = this
      app.setupDB ->
        self.callback()

    'Signup with complete info':
      topic: (db)->
        data = { phone_number: "passenger1", password: "123456", nickname: "liufy" }
   
        data = JSON.stringify(data)
        browser.post('/passenger/signup', { body: 'json_data=' + data}, this.callback)
  
      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)
        console.dir(res.body)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('passenger test')
suite.addBatch(batch1)
suite.export(module)

