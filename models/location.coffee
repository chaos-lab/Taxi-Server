# Location collection
mongodb = require('mongodb')

# Location schema
# { name: "xxx", position:[118.23432, 32.4343] }

module.exports = Location =
  setup: (db) ->
    this.collection = new mongodb.Collection(db, 'locations')

    this.collection.ensureIndex {position: '2d'}, (err, name)->

