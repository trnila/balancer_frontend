#!/bin/sh
yarn build
rsync -av --delete dist/ balancer:/var/www/

