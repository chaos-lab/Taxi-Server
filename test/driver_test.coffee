tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')

# app init
app = require('../webserver')
browser = tobi.createBrowser(app)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('driver test')

suite.addBatch
  "setup - ":
    topic: ->
      # app.setupDB(this.callback) doesn't work!!!
      self = this
      app.setupDB (db)->
        helper.cleanDB db, ->
          self.callback()

      # tells vows it's async, or coffee will return last value, which breaks the framework.
      return

    'visists hello world':
      topic: ->
        browser.get('/', {}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)

suite.addBatch
  'before sigin - ':
    'signup with incomplete info':
      topic: ->
        data = { phone_number: "driver1", password: "123456", nickname:"cang" }
        data = JSON.stringify(data)
        browser.post('/driver/signup', { body: 'json_data=' + data}, this.callback)
        return

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 2)

    'update location before signin':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
        return

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 1)

    "signin with inexistent account":
      topic: ->
        data = { phone_number: "xxxx", password: "abcd234" }
        data = JSON.stringify(data)
        browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
        return

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 101)

suite.addBatch
  "signup with complete info":
    topic: ->
      data = { phone_number: "driver1", password: "123456", nickname: "cang", car_number: "ABCD" }
      data = JSON.stringify(data)
      browser.post('/driver/signup', { body: 'json_data=' + data}, this.callback)
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  "signup with duplicate phone number":
    topic: (e, rs)->
      data = { phone_number: "driver1", password: "123456", nickname: "xxxx", car_number: "ABCD" }
      data = JSON.stringify(data)
      browser.post '/driver/signup', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  "signup with duplicate nickname":
    topic: (e, rs)->
      data = { phone_number: "159234843234", password: "123456", nickname: "cang", car_number: "ABCD" }
      data = JSON.stringify(data)
      browser.post '/driver/signup', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 102)

suite.addBatch
  "signin with incorrect credentials":
    topic: ->
      data = { phone_number: "driver1", password: "abcd234" }
      data = JSON.stringify(data)
      browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  "signin with correct credentials":
    topic: ->
      data = { phone_number: "driver1", password: "123456" }
      data = JSON.stringify(data)
      browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isObject(res.body.self)
      assert.equal(res.body.self.nickname, 'cang')

suite.addBatch
  'after sigin - ':
    'visit passenger path':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/passenger/location/update', { body: 'json_data=' + data}, this.callback)
        return

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 1)

    'update location':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)

    'refresh':
      topic: ->
        browser.get('/driver/refresh', {}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)
        assert.isArray(res.body.messages)

    'update state':
      topic: ->
        data = { state: 2 }
        data = JSON.stringify(data)
        browser.post('/driver/taxi/update', { body: 'json_data=' + data}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)

suite.addBatch
  'signout':
    topic: ->
      browser.post('/driver/signout', {}, this.callback)
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'update location after signout':
    topic: ->
      data = { latitude: 34.545, longitude: 118.324 }
      data = JSON.stringify(data)
      browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 1)

suite.export(module)

