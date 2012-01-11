tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')
querystring = require('querystring')

p1 = { phone_number: "13913391280", password: "123", nickname: "souriki", role: ["passenger", "user"], state: 2, location:{ latitude: 118.2342, longitude: 32.43432 } }
d1 = { phone_number: "13851403984", password: "123", nickname: "liuq", role: ["driver", "user"], state: 2, car_number: "ABCD", taxi_state: 1, location:{ latitude: 118.2342, longitude: 32.43432 } }

# app init
app = require('../webserver')
passenger = tobi.createBrowser(app)
driver = tobi.createBrowser(app)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('seed test data')

suite.addBatch
  "setup":
    topic: ->
      self = this
      app.db.open ->
        helper.createUser app.db, p1, ->
          helper.createUser app.db, d1, ->
            helper.signin_passenger passenger, { phone_number: p1.phone_number, password: p1.password }, (res, $) ->
              helper.signin_driver driver, { phone_number: d1.phone_number, password: d1.password }, (res, $) ->
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
        assert.equal(res.body.taxis[0].phone_number, d1.phone_number)

suite.addBatch
  "should be able for passenger to send taxi call":
    topic: ->
      data = { origin: { latitude: 118.2342, longitude: 32.43432 }, driver: d1.phone_number,  key: new Date().valueOf() }
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
  'should be able for passenger to update location':
    topic: (res, $)->
      data = { latitude: 34.545, longitude: 118.324 }
      data = JSON.stringify(data)
      passenger.post '/passenger/location/update', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for driver to receive location update':
    topic: (res, $)->
      driver.get '/driver/refresh', {}, this.callback
      return
      
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal res.body.messages[0].type, "location-update"
      assert.equal res.body.messages[0].phone_number, p1.phone_number

suite.addBatch
  'should be able for driver to update location':
    topic: (res, $)->
      data = { latitude: 34.545, longitude: 118.324 }
      data = JSON.stringify(data)
      driver.post '/driver/location/update', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for passenger to receive location update':
    topic: (res, $)->
      passenger.get '/passenger/refresh', {}, this.callback
      return
      
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal res.body.messages[0].type, "location-update"
      assert.equal res.body.messages[0].phone_number, d1.phone_number

suite.addBatch
  'should be able for driver to complete taxi call':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      driver.post '/service/complete', { body: 'json_data=' + data}, this.callback
      return
  
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for passenger to receive taxi-call-complete':
    topic: (res, $)->
      passenger.get '/passenger/refresh', {}, this.callback
      return
      
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length > 0
      assert.equal res.body.messages[0].type, "call-taxi-complete"
      assert.equal res.body.messages[0].id, driver.service_id

suite.addBatch
  'should be able for passenger to evaluate service':
    topic: (res, $)->
      score = new Date().valueOf()%5
      score = 1 if score == 0
      data = { id: driver.service_id, score: score, comment: "Good!" }
      data = JSON.stringify(data)
      passenger.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for driver to evaluate service':
    topic: (res, $)->
      score = new Date().valueOf()%5
      score = 1 if score == 0
      data = { id: driver.service_id, score: score, comment: "bad!" }
      data = JSON.stringify(data)
      driver.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for driver to get evaluations about passenger':
    topic: (res, $)->
      data = {phone_number: p1.phone_number, end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      driver.get '/service/user/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.evaluations)
      assert.equal(res.body.evaluations[0].evaluator, d1.nickname)

suite.addBatch
  'should be able for passenger to get evaluations about driver':
    topic: (res, $)->
      data = {phone_number: d1.phone_number, end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      driver.get '/service/user/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.evaluations)
      assert.equal(res.body.evaluations[0].evaluator, p1.nickname)

suite.export(module)

