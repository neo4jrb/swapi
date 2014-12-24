#!/bin/bash

bundle
bundle exec rake neo4j:install[community-2.1.6,development]
bundle exec rake neo4j:config[development,1138]
bundle exec rake neo4j:start
bundle exec rake import:api

# May not work on non OS X
open http://localhost:1138

