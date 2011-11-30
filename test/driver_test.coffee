tobi = require('tobi')
assert = require('assert')
should = require('should')
vows   = require('vows')
helper = require('./helper')

# app init
app = require('../webserver')
browser = tobi.createBrowser(app)

batch1 =
  "before signin":
    topic: ->
      # app.setupDB(this.callback) doesn't work!!!
      self = this
      app.setupDB (db)->
        helper.cleanDB(db, self.callback)

    'visists hello world':
      topic: ->
        browser.get('/', {}, this.callback)
        return undefined

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)

    'signup with incomplete info':
      topic: ->
        data = { phone_number: "driver1", password: "123456", nickname:"cang" }
        data = JSON.stringify(data)
        browser.post('/passenger/signup', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(1, res.body.status)

    'update location before signin':
      topic: ->
        data = { latitude: 34.545, longitude: 118.324 }
        data = JSON.stringify(data)
        browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(1, res.body.status)

    "signin with inexistent account":
      topic: ->
        data = { phone_number: "xxxx", password: "abcd234" }
        data = JSON.stringify(data)
        browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(1, res.body.status)

    "signup with complete info":
      topic: ->
        data = { phone_number: "driver1", password: "123456", nickname: "cang" }
        data = JSON.stringify(data)
        browser.post('/driver/signup', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)

batch2 =
  "after signin":
    "signin with incorrect credentials":
      topic: ->
        data = { phone_number: "driver1", password: "abcd234" }
        data = JSON.stringify(data)
        browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should fail': (res, $) ->
        res.should.have.status(200)
        assert.equal(1, res.body.status)

    "signin with correct credentials":
      topic: ->
        data = { phone_number: "driver1", password: "123456" }
        data = JSON.stringify(data)
        browser.post('/driver/signin', { body: 'json_data=' + data}, this.callback)
        return undefined

      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)
        assert.isObject(res.body.self)
        assert.equal('liufy', res.body.self.nickname)

      'visit passenger path':
        topic: ->
          data = { latitude: 34.545, longitude: 118.324 }
          data = JSON.stringify(data)
          browser.post('/passenger/location/update', { body: 'json_data=' + data}, this.callback)
          return undefined

        'should fail': (res, $) ->
          res.should.have.status(200)
          assert.equal(1, res.body.status)

      'update location':
        topic: ->
          data = { latitude: 34.545, longitude: 118.324 }
          data = JSON.stringify(data)
          browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
          return undefined

        'should succeed': (res, $) ->
          res.should.have.status(200)
          assert.equal(0, res.body.status)

      'refresh':
        topic: ->
          browser.get('/driver/refresh', {}, this.callback)
          return undefined

        'should succeed': (res, $) ->
          res.should.have.status(200)
          assert.equal(0, res.body.status)
          assert.isArray(0, res.body.messages)

      'update state':
        topic: ->
          data = { state: 2 }
          data = JSON.stringify(data)
          browser.get('/driver/taxi/update', { body: 'json_data=' + data}, this.callback)
          return undefined

        'should succeed': (res, $) ->
          res.should.have.status(200)
          assert.equal(0, res.body.status)
          assert.isArray(0, res.body.taxis)

batch3 =
  "after signout":
    'signout':
      topic: ->
        browser.post('/driver/signout', {}, this.callback)
        return undefined
  
      'should succeed': (res, $) ->
        res.should.have.status(200)
        assert.equal(0, res.body.status)

      'update location after signout':
        topic: ->
          data = { latitude: 34.545, longitude: 118.324 }
          data = JSON.stringify(data)
          browser.post('/driver/location/update', { body: 'json_data=' + data}, this.callback)
          return undefined

        'should fail': (res, $) ->
          res.should.have.status(200)
          assert.equal(1, res.body.status)

# Batches  are executed sequentially.
# Contexts are executed in parallel.
suite = vows.describe('driver test')
suite.addBatch(batch1)
suite.addBatch(batch2)
suite.addBatch(batch3)
suite.export(module)

