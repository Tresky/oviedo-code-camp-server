require 'rubygems'
require 'sinatra'
require 'json'
require 'rack/recaptcha'
require 'pony'
require 'httparty'

$stdout.sync = true

use Rack::Recaptcha, :public_key => '6LdZXBUUAAAAAAcwiwus50XnDLbLx-yI16XYL8Ov', :private_key => '6LdZXBUUAAAAAIDdtkCWTDS2Ca7RgkcizUgUYq6U'
helpers Rack::Recaptcha::Helpers

require './application'
run Sinatra::Application
