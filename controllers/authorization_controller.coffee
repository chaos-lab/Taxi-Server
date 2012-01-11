# controllers for authorization

_ = require("underscore")

class AuthorizationController

  constructor: ->

  ##
  # restrict to roles
  ##
  restrict_to: (roles) ->
    roles = [roles] if _.isString(roles)
    (req, res, next) ->
      if req.current_user && _.intersection(req.current_user.role, roles).length > 0
        next()
      else
        logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
        res.json { status: 1, message: 'Unauthorized' }

  ##
  # restrict to login users
  ##
  restrict_to_user: (req, res, next) ->
    if req.current_user && _.include(req.current_user.role, "user")
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  ##
  # restrict to login passengers
  ##
  restrict_to_passenger: (req, res, next) ->
    if req.current_user && _.include(req.current_user.role, "passenger")
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  ##
  # restrict to login drivers
  ##
  restrict_to_driver:  (req, res, next) ->
    if req.current_user && _.include(req.current_user.role, "user")
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

module.exports = AuthorizationController
