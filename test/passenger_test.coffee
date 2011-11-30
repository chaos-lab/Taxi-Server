tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')

# app init
app = require('../webserver')
browser = tobi.createBrowser(app)

batch1 =
  "passenger":
    topic: ->
      # app.setupDB(this.callback) doesn't work!!!
      self = this
      app.setupDB (db)->
        helper.cleanDB(db, self.callback)

    'Signup with complete info':
      topic: ->
        data = { phone_number: "passenger1", password: "123456", nickname: "liufy" }
   
        data = JSON.stringify(data)
        browser.post('/passenger/signup', { body: 'json_data=' + data}, this.callback)
  
      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('passenger test')
suite.addBatch(batch1)
suite.export(module)

