#
# Run all tests
#
test: 
	node_modules/.bin/vows -v --sepc test/passenger_test.coffee

.PHONY:	test
