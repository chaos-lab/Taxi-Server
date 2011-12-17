# controllers for authorization

winston = require('winston')

User = require('../models/user')

class AuthorizationController

  constructor: ->

  restrict_to_user: (req, res, next) ->
    if req.current_user
      next()
    else
      winston.warn("AuthorizationController", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  restrict_to_passenger: (req, res, next) ->
    if (req.current_user && req.current_user.role == 1)
      next()
    else
      winston.warn("AuthorizationController", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      winston.warn("AuthorizationController", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

module.exports = AuthorizationController
