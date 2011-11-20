
# How to run

   First install node.js: 

     yum install nodejs

   Install npm: 

     curl http://npmjs.org/install.sh | sh

   install packages: 

     npm install

   run: 

     node server.js

# How to test

   First start node.js:

     node server.js

   Install necessary gems(ensure ruby is installed): 

     # unnecessary if bundler is already installed
     gem install bundler
     bundle install

   run test: 

     rake spec

