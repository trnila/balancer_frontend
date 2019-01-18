#!/bin/sh
yarn build
rsync -av dist/ balancer:/var/www/

