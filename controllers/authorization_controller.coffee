# controllers for authorization

class AuthorizationController

  constructor: ->

  ##
  # restrict to login users
  ##
  restrict_to_user: (req, res, next) ->
    if req.current_user
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  ##
  # restrict to login passengers
  ##
  restrict_to_passenger: (req, res, next) ->
    if (req.current_user && req.current_user.role == 1)
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

  ##
  # restrict to login drivers
  ##
  restrict_to_driver:  (req, res, next) ->
    if (req.current_user && req.current_user.role == 2)
      next()
    else
      logger.warning("AuthorizationController - %s", "Unauthorized driver access to #{req.url}")
      res.json { status: 1, message: 'Unauthorized' }

module.exports = AuthorizationController
