tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')

# app init
app = require('../webserver')
passenger = tobi.createBrowser(app)
driver = tobi.createBrowser(app)


# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('taxi call & cancel test')

suite.addBatch
  "setup":
    topic: ->
      self = this
      p1 = { phone_number: "passenger1", password: "123456", nickname: "liufy", role: 1, state: 2, location:{ latitude: 118.2342, longitude: 32.43432 } }
      d1 = { phone_number: "driver1", password: "123456", nickname: "cang", role: 2, state: 2, car_number: "ABCD", taxi_state: 1, location:{ latitude: 118.2342, longitude: 32.43432 } }
      helper.cleanDB app.db, ->
        helper.createUser app.db, p1, ->
          helper.createUser app.db, d1, ->
            helper.signin_passenger passenger, { phone_number: "passenger1", password: "123456" }, (res, $) ->
              helper.signin_driver driver, { phone_number: "driver1", password: "123456" }, (res, $) ->
                self.callback()

      # tells vows it's async, or coffee will return last value, which breaks the framework.
      return

    "should be able for passenger to get near taxi":
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        passenger.get '/taxi/near', { body: 'json_data=' + data}, this.callback
        return
  
      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)
        assert.isTrue res.body.taxis.length > 0
        assert.equal(res.body.taxis[0].phone_number, "driver1")
        assert.isNotNull(res.body.taxis[0].stats)
        assert.isNotNull(res.body.taxis[0].stats.service_count)
        assert.isNotNull(res.body.taxis[0].stats.average_score)
        assert.isNotNull(res.body.taxis[0].stats.evaluation_count)

suite.addBatch
  "should be able for passenger to send taxi call":
    topic: ->
      data = { origin: { latitude: 118.2342, longitude: 32.43432 }, driver: "driver1",  key: 35432543 }
      data = JSON.stringify(data)
      passenger.post '/service/create', { body: 'json_data=' + data}, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNumber res.body.id
      driver.service_id = res.body.id

suite.addBatch
  'should be able for driver to receive taxi call':
    topic: (res, $)->
      driver.get '/driver/refresh', {}, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal driver.service_id, res.body.messages[0].id
      assert.equal "call-taxi", res.body.messages[0].type

suite.addBatch
  'should be able for driver to reply taxi call':
    topic: (res, $)->
      data = { id: driver.service_id, accept: true }
      data = JSON.stringify(data)
      driver.post '/service/reply', { body: 'json_data=' + data}, this.callback
      return
  
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for passenger to receive taxi call reply':
    topic: (res, $)->
      passenger.get '/passenger/refresh', {}, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal res.body.messages[0].id, driver.service_id
      assert.equal res.body.messages[0].type, "call-taxi-reply"
      assert.equal res.body.messages[0].accept, true

suite.addBatch
  'should be able for passenger to cancel taxi call':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      passenger.post '/service/cancel', { body: 'json_data=' + data}, this.callback
      return
    
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for driver to receive taxi call cancel':
    topic: (res, $)->
      driver.get '/driver/refresh', {}, this.callback
      return
      
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal driver.service_id, res.body.messages[0].id
      assert.equal res.body.messages[0].type, "call-taxi-cancel"

suite.addBatch
  'should be unable for driver to reply taxi call after cancelled':
    topic: (res, $)->
      data = { id: driver.service_id, accept: false }
      data = JSON.stringify(data)
      driver.post '/service/reply', { body: 'json_data=' + data}, this.callback
      return
  
    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  'should be unable for passenger to cancel taxi call after cancelled':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      passenger.post '/service/cancel', { body: 'json_data=' + data}, this.callback
      return
    
    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  'should be unable for driver to complete taxi call after cancelled':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      driver.post '/service/complete', { body: 'json_data=' + data}, this.callback
      return
  
    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  'should be unable for passenger to evaluate cancelled service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 4, comment: "Good!" }
      data = JSON.stringify(data)
      passenger.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

  'should be unable for driver to evaluate cancelled service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 3, comment: "bad!" }
      data = JSON.stringify(data)
      driver.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.export(module)

