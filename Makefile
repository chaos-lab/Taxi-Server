#
# Run all tests
#
test: 
	node_modules/.bin/vows --spec test/passenger_test.coffee test/driver_test.coffee test/taxi_call_test.coffee

run:
	NODE_ENV=production node server.js

.PHONY: test
