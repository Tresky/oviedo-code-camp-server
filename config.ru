require 'dotenv/load'
require 'rubygems'
require 'sinatra'
require 'json'
require 'rack/recaptcha'
require 'pony'
require 'httparty'
require 'stripe'


# For Heroku logging
$stdout.sync = true

# Set keys for
set :stripe_publishable_key, ENV['STRIPE_PUBLISHABLE_KEY']
set :stripe_secret_key, ENV['STRIPE_SECRET_KEY']

Stripe.api_key = settings.stripe_secret_key

use Rack::Recaptcha, :public_key => '6LdZXBUUAAAAAAcwiwus50XnDLbLx-yI16XYL8Ov', :private_key => '6LdZXBUUAAAAAIDdtkCWTDS2Ca7RgkcizUgUYq6U'
helpers Rack::Recaptcha::Helpers

require './application'
run Sinatra::Application
