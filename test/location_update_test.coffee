tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')
querystring = require('querystring')

p1 = { phone_number: "passenger1", password: "123456", name: "liufy", role: ["user", "passenger"], state: 2, location:{ latitude: 118.2342, longitude: 32.43432 } }
d1 = { phone_number: "driver1", password: "123456", name: "cang", role: ["user", "driver"], state: 2, car_number: "ABCD", taxi_state: 1, location:{ latitude: 118.2342, longitude: 32.43432 } }

# app init
app = require('../webserver')
passenger = tobi.createBrowser(app)
driver = tobi.createBrowser(app)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('test location update & evaluate')

suite.addBatch
  "setup":
    topic: ->
      self = this
      helper.cleanDB app.db, ->
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
        assert.equal(res.body.taxis[0].name, d1.name)

suite.addBatch
  "should be able for passenger to send taxi call":
    topic: ->
      data = { origin: { latitude: 118.2342, longitude: 32.43432 }, driver: d1.name,  key: 35432543 }
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
      assert.equal res.body.messages[0].name, p1.name

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
      assert.equal res.body.messages[0].name, d1.name

suite.addBatch
  'should be unable for passenger to evaluate uncompleted service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 4, comment: "Good!" }
      data = JSON.stringify(data)
      passenger.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

  'should be unable for driver to evaluate uncompleted service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 3, comment: "bad!" }
      data = JSON.stringify(data)
      driver.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

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

  'should be unable for passenger to cancel taxi call after completed':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      passenger.post '/service/cancel', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

  'should be unable for driver to reply taxi call after completed':
    topic: (res, $)->
      data = { id: driver.service_id, accept: false }
      data = JSON.stringify(data)
      driver.post '/service/reply', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

  'should be unable for driver to complete taxi call after completed':
    topic: (res, $)->
      data = { id: driver.service_id }
      data = JSON.stringify(data)
      driver.post '/service/complete', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

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
  'should be unable for driver to receive location update after service is completed':
    topic: (res, $)->
      driver.get '/driver/refresh', {}, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length == 0

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
  'should be unable for passenger to receive location update after service is completed':
    topic: (res, $)->
      passenger.get '/passenger/refresh', {}, this.callback
      return
      
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isTrue res.body.messages.length == 0

suite.addBatch
  'should be able for passenger to evaluate service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 4, comment: "Good!" }
      data = JSON.stringify(data)
      passenger.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for passenger to get service evaluations':
    topic: (res, $)->
      data = {ids: [driver.service_id]}
      data = JSON.stringify(data)
      passenger.get '/service/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.equal(res.body[driver.service_id].passenger_evaluation.score, 4)
      assert.equal(res.body[driver.service_id].passenger_evaluation.comment, "Good!")

suite.addBatch
  'should be able for driver to evaluate service':
    topic: (res, $)->
      data = { id: driver.service_id, score: 3, comment: "bad!" }
      data = JSON.stringify(data)
      driver.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'should be able for driver to get service evaluations':
    topic: (res, $)->
      data = {ids: [driver.service_id]}
      data = JSON.stringify(data)
      driver.get '/service/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.equal(res.body[driver.service_id].passenger_evaluation.score, 4)
      assert.equal(res.body[driver.service_id].passenger_evaluation.comment, "Good!")
      assert.equal(res.body[driver.service_id].driver_evaluation.score, 3)
      assert.equal(res.body[driver.service_id].driver_evaluation.comment, "bad!")

suite.addBatch
  'should be unable for passenger to evaluate service twice':
    topic: (res, $)->
      data = { id: driver.service_id, score: 4, comment: "Good!" }
      data = JSON.stringify(data)
      passenger.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 103)

  'should be unable for driver to evaluate service twice':
    topic: (res, $)->
      data = { id: driver.service_id, score: 3, comment: "bad!" }
      data = JSON.stringify(data)
      driver.post '/service/evaluate', { body: 'json_data=' + data }, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 103)

suite.addBatch
  'should be able for driver to get evaluations about passenger':
    topic: (res, $)->
      data = {name: p1.name, end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      driver.get '/service/user/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.evaluations)
      assert.equal(res.body.evaluations[0].score, 3)
      assert.equal(res.body.evaluations[0].comment, 'bad!')
      assert.equal(res.body.evaluations[0].evaluator, d1.name)

suite.addBatch
  'should be able for passenger to get evaluations about driver':
    topic: (res, $)->
      data = {name: d1.name, end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      driver.get '/service/user/evaluations?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.evaluations)
      assert.equal(res.body.evaluations[0].score, 4)
      assert.equal(res.body.evaluations[0].comment, 'Good!')
      assert.equal(res.body.evaluations[0].evaluator, p1.name)

suite.addBatch
  'should be able for passenger to get history':
    topic: (res, $)->
      data = {end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      passenger.get '/service/history?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isArray(res.body.services)
      assert.equal(res.body.services[0].id, driver.service_id)
      assert.equal(res.body.services[0].state, 3)
      assert.isObject(res.body.services[0].origin)
      assert.isObject(res.body.services[0].driver)
      assert.isUndefined(res.body.services[0].passenger)
      assert.equal(res.body.services[0].driver.phone_number, d1.phone_number)
      assert.equal(res.body.services[0].driver.name, d1.name)
      assert.equal(res.body.services[0].driver.car_number, d1.car_number)
      assert.isObject(res.body.services[0].driver.stats)
      assert.equal(res.body.services[0].driver.stats.average_score, 4)
      assert.equal(res.body.services[0].driver.stats.service_count, 1)
      assert.equal(res.body.services[0].driver.stats.evaluation_count, 1)
      assert.isObject(res.body.services[0].driver_evaluation)
      assert.equal(res.body.services[0].driver_evaluation.score, 3)
      assert.equal(res.body.services[0].driver_evaluation.comment, 'bad!')
      assert.isObject(res.body.services[0].passenger_evaluation)
      assert.equal(res.body.services[0].passenger_evaluation.score, 4)
      assert.equal(res.body.services[0].passenger_evaluation.comment, 'Good!')

suite.addBatch
  'should be able for driver to get history':
    topic: (res, $)->
      data = {end_time: new Date().valueOf()}
      data = JSON.stringify(data)
      driver.get '/service/history?' + querystring.stringify({json_data: data}), this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.services)
      assert.equal(res.body.services[0].id, driver.service_id)
      assert.equal(res.body.services[0].state, 3)
      assert.isObject(res.body.services[0].origin)
      assert.isObject(res.body.services[0].passenger)
      assert.isUndefined(res.body.services[0].driver)
      assert.equal(res.body.services[0].passenger.phone_number, p1.phone_number)
      assert.equal(res.body.services[0].passenger.name, p1.name)
      assert.isObject(res.body.services[0].passenger.stats)
      assert.equal(res.body.services[0].passenger.stats.average_score, 3)
      assert.equal(res.body.services[0].passenger.stats.service_count, 1)
      assert.equal(res.body.services[0].passenger.stats.evaluation_count, 1)
      assert.isObject(res.body.services[0].driver_evaluation)
      assert.equal(res.body.services[0].driver_evaluation.score, 3)
      assert.equal(res.body.services[0].driver_evaluation.comment, 'bad!')
      assert.isObject(res.body.services[0].passenger_evaluation)
      assert.equal(res.body.services[0].passenger_evaluation.score, 4)
      assert.equal(res.body.services[0].passenger_evaluation.comment, 'Good!')

suite.export(module)

