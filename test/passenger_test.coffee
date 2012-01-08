events = require("events")
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
suite = vows.describe('passenger test')

suite.addBatch
  "setup - ":
    topic: ->
      self = this
      helper.cleanDB app.db, ->
        self.callback()

      # tells vows it's async, or coffee will return last value, which breaks the framework.
      return

    'visits hello world':
      topic: ->
        browser.get('/', {}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)

suite.addBatch
  'before signin - ':
    'signup with incomplete info':
      topic: (e, res)->
        data = { phone_number: "passenger1", password: "123456" }
        data = JSON.stringify(data)
        self = this
        browser.post '/passenger/signup', { body: 'json_data=' + data}, this.callback
        return
  
      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 2)
  
    'update location before signin':
      topic: (e, res)->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post '/passenger/location/update', { body: 'json_data=' + data}, this.callback
        return
  
      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 1)
  
    "signin with inexistent account":
      topic: (e, res)->
        data = { phone_number: "xxxx", password: "abcd234" }
        data = JSON.stringify(data)
        browser.post '/passenger/signin', { body: 'json_data=' + data}, this.callback
        return
  
      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 101)

suite.addBatch
  "signup with complete info":
    topic: (e, rs)->
      data = { phone_number: "passenger1", password: "123456", name: "liufy" }
      data = JSON.stringify(data)
      browser.post '/passenger/signup', { body: 'json_data=' + data}, this.callback
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  "signup with duplicate phone number":
    topic: (e, rs)->
      data = { phone_number: "passenger1", password: "123456", name: "zhang" }
      data = JSON.stringify(data)
      browser.post '/passenger/signup', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  "signup with duplicate name":
    topic: (e, rs)->
      data = { phone_number: "159234843234", password: "123456", name: "liufy" }
      data = JSON.stringify(data)
      browser.post '/passenger/signup', { body: 'json_data=' + data}, this.callback
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 102)

suite.addBatch
  "signin with incorrect credentials":
    topic: ->
      data = { phone_number: "passenger1", password: "abcd234" }
      data = JSON.stringify(data)
      browser.post('/passenger/signin', { body: 'json_data=' + data}, this.callback)
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 101)

suite.addBatch
  "signin with correct credentials":
    topic: ->
      data = { phone_number: "passenger1", password: "123456" }
      data = JSON.stringify(data)
      browser.post('/passenger/signin', { body: 'json_data=' + data}, this.callback)
      return

    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)
      assert.isNotNull(res.body.self)
      assert.isNotNull(res.body.self.stats)
      assert.isNotNull(res.body.self.stats.service_count)
      assert.isNotNull(res.body.self.stats.average_score)
      assert.isNotNull(res.body.self.stats.evaluation_count)
      assert.equal('liufy', res.body.self.name)

suite.addBatch
  "after signin - ":
    'visit driver path':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
        return

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 1)

    'update location':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/passenger/location/update', { body: 'json_data=' + data}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)

    'refresh':
      topic: ->
        browser.get('/passenger/refresh', {}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)
        assert.isArray(res.body.messages)

    'get near taxi':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.get('/taxi/near', { body: 'json_data=' + data}, this.callback)
        return

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(res.body.status, 0)
        assert.isArray(res.body.taxis)

suite.addBatch
  'signout':
    topic: ->
      browser.post('/passenger/signout', {}, this.callback)
      return
  
    'should succeed': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 0)

suite.addBatch
  'update location after signout':
    topic: ->
      data = { latitude: 34.545, longitude: 118.324 }
      data = JSON.stringify(data)
      browser.post('/passenger/location/update', { body: 'json_data=' + data}, this.callback)
      return

    'should fail': (res, $) ->
      res.should.have.status(200)
      assert.equal(res.body.status, 1)

suite.export(module)

