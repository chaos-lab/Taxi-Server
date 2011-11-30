tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')

# app init
app = require('../webserver')
passenger = tobi.createBrowser(app)
driver = tobi.createBrowser(app)

batch1 =
  "call taxi":
    topic: ->
      # app.setupDB(this.callback) doesn't work!!!
      self = this
      app.setupDB (db)->
        p1 = { phone_number: "passenger1", password: "123456", nickname: "liufy", role: 1, state: 0, location:{ latitude: 118.2342, longitude: 32.43432 } }
        d1 = { phone_number: "driver1", password: "123456", nickname: "cang", role: 2, taxi_number: "ABCD", state: 0, taxi_state: 1, location:{ latitude: 118.2342, longitude: 32.43432 } }
        helper.cleanDB db, ->
          helper.createUser db, p1, ->
            helper.createUser db, d1, ->
              helper.signin_passenger passenger, { phone_number: "passenger1", password: "123456" }, (res, $) ->
                helper.signin_driver driver, { phone_number: "driver1", password: "123456" }, (res, $) ->
                  self.callback()

      # tells vows it's async, or coffee will return last value, which breaks the framework.
      return undefined

    "should be able for passenger to get near taxi":
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        passenger.get '/taxi/near', { body: 'json_data=' + data}, this.callback
        return undefined
  
      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)
        assert.isTrue res.body.taxis.length > 0
        assert.equal("driver1", res.body.taxis[0].phone_number)

    "should be able for passenger to send taxi call":
      topic: ->
        data = { location: { latitude: 118.2342, longitude: 32.43432 }, driver: "driver1",  key: 35432543 }
        data = JSON.stringify(data)
        passenger.post('/service/create', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)
        assert.isNumber res.body.id
        driver.service_id = res.body.id

      'should be able for driver to receive taxi call':
        topic: (res, $)->
          driver.get '/driver/refresh', {}, this.callback
          return undefined

        'should succeed': (res, $) ->
          res.should.have.status(200)
          assert.equal(0, res.body.status)
          assert.isTrue res.body.messages.length > 0
          assert.equal driver.service_id, res.body.messages[0].id
          assert.equal "call-taxi", res.body.messages[0].type

        'should be able for driver to reply taxi call':
          topic: (res, $)->
            data = { id: driver.service_id, accept: true }
            data = JSON.stringify(data)
            driver.post '/service/reply', { body: 'json_data=' + data}, this.callback
            return undefined
  
          'should succeed': (res, $) ->
            res.should.have.status(200)
            assert.equal(0, res.body.status)

          'should be able for passenger to receive taxi call reply':
            topic: (res, $)->
              passenger.get '/passenger/refresh', {}, this.callback
              return undefined

            'should succeed': (res, $) ->
              res.should.have.status(200)
              assert.equal(0, res.body.status)
              assert.isTrue res.body.messages.length > 0
              assert.equal driver.service_id, res.body.messages[0].id
              assert.equal "call-taxi-reply", res.body.messages[0].type
              assert.equal true, res.body.messages[0].accept

            'should be able for passenger to cancel taxi call':
              topic: (res, $)->
                data = { id: driver.service_id }
                data = JSON.stringify(data)
                passenger.post '/service/cancel', { body: 'json_data=' + data}, this.callback
                return undefined
    
              'should succeed': (res, $) ->
                res.should.have.status(200)
                assert.equal(0, res.body.status)

              'should be able for driver to receive taxi call cancel':
                topic: (res, $)->
                  driver.get '/driver/refresh', {}, this.callback
                  return undefined
      
                'should succeed': (res, $) ->
                  res.should.have.status(200)
                  assert.equal(0, res.body.status)
                  assert.isTrue res.body.messages.length > 0
                  assert.equal driver.service_id, res.body.messages[0].id
                  assert.equal "call-taxi-reply", res.body.messages[0].type
                  assert.equal true, res.body.messages[0].accept

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('taxi call test')
suite.addBatch(batch1)
suite.export(module)

