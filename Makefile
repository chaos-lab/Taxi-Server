#
# Run all tests
#
test: 
	node_modules/.bin/vows --spec test/passenger_test.coffee test/driver_test.coffee test/taxi_call_test.coffee test/location_update_test.coffee

seed: 
	node_modules/.bin/vows --spec seed/seed.coffee 

.PHONY: test seed
