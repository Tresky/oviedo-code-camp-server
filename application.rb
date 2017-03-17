require 'awesome_print'

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/cross_origin'

require './helpers'
require './mailer'
require './environments'

# Create a model for the Signup objects.
# Only need one model, so just put in this file.
class Signup < ActiveRecord::Base
  # Maybe add validators if I get around to it.
end

class Camp < ActiveRecord::Base
  # Maybe add validators if I get around to it.

  def self.is_class_full?(name)
    camp = Camp.where(:name => name).first
    puts 'Amount'
    puts camp.num_registered
    camp.num_registered >= 12
  end

  def meet_age_requirement?(completed_grade)
    if self.name.include?('elem')
      completed_grade >= 4 && completed_grade < 6
    elsif self.name.include?('middle')
      completed_grade >= 6 && completed_grade < 9
    end
  end
end

before do
  content_type :json
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => ['POST'],
          'Access-Control-Allow-Headers' => ['Content-Type', 'Accept']
end

set :protection, false
set :public_dir, Proc.new { File.join(root, "_site") }

set :allow_origin, ['https://oviedocodecamp.com', 'localhost:9000']
set :allow_methods, [:get, :post, :options]
set :allow_credentials, true
set :max_age, "1728000"
set :expose_headers, ['Content-Type']

configure do
  enable :cross_origin
end

options "*" do
    response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"

    response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"

    200
end

get '/classes' do
  @classes = Camp.all.order :id
  @classes.to_json
end

get '/.well-known/acme-challenge/:token' do
    data = []
    if ENV['ACME_KEY'] && ENV['ACME_TOKEN']
      data << { key: ENV['ACME_KEY'], token: ENV['ACME_TOKEN'] }
    else
      ENV.each do |k, v|
        if d = k.match(/^ACME_KEY_([0-9]+)/)
          index = d[1]
          data << { key: v, token: ENV["ACME_TOKEN_#{index}"] }
        end
      end
    end

    data.each do |e|
      if env['PATH_INFO'] == "/.well-known/acme-challenge/#{e[:token]}"
        status 200
        content_type 'text/plain'
        body "#{e[:key]}"
        "#{e[:key]}"
        return
      end
    end

    status 500
    content_type 'text/plain'
    body 'No key found'
    'No key found'
  end

post '/send_email' do
  puts 'Endpoint Hit'
  puts 'Verifying ReCaptcha'
  puts 'Body'
  body = 'secret=' + ENV['RECAPTCHA_SECRET_KEY'].to_s + '&response=' + params['g-recaptcha-response']
  puts body
  response = HTTParty.post('https://www.google.com/recaptcha/api/siteverify',
    :body => body,
    :headers => {
      'Content-Type' => 'application/x-www-form-urlencoded;charset=utf-8'
    })

  puts 'ReCaptcha Result'
  puts response

  if response['success']
    res = Mailer.send 'hello@tylerpetresky.com', params['name'] + ' <' + params['email'] + '>', '[Oviedo Code Camp] Contact Form', params['message']
    content_type :json
    if res
      { :message => 'success' }.to_json
    else
      { :message => 'failure_email' }.to_json
    end
  else
    puts response
    { :message => 'failure_captcha' }.to_json
  end
end

post '/register' do
  @amount = 35000

  valid_params = Helpers.pull_params params, [
    'parent_first_name',
    'parent_last_name',
    'child_first_name',
    'child_last_name',
    'child_completed_grade',
    't_shirt_size',
    'camp_selection',
    'stripeEmail',
    'stripeToken'
  ]

  if (!params.has_key?('terms') || !(params[:terms].eql?('true') || params[:terms].eql?(true)))
    return { :message => 'failure_mustagree' }.to_json
  end

  if valid_params
    # Verify that the class is not full already
    if Camp.is_class_full?(params[:camp_selection])
      return { :message => 'failure_classfull' }.to_json
    end

    # Verify that the camper meets the age requirement
    @class = Camp.where(:name => params[:camp_selection]).first
    if !@class.meet_age_requirement?(params[:child_completed_grade].to_i)
      return { :message => 'failure_wrongage' }.to_json
    end

    # Create a token to test with in development
    if ENV['RACK_ENV'].eql?('development')
      begin
        params[:stripeToken] = Stripe::Token.create(
          :card => {
            :number => "4242424242424242",
            :exp_month => 2,
            :exp_year => 2018,
            :cvc => "314"
          }
        ).id
      rescue Stripe::StripeError => e
        return { :message => 'failure_creatingtesttoken', :error => e }.to_json
      end
    end

    begin
      @customer = Stripe::Customer.create(
        email: params[:stripeEmail].to_s,
        source: params[:stripeToken].to_s,
        metadata: {
          parent_first_name: params[:parent_first_name].to_s,
          parent_last_name: params[:parent_last_name].to_s,
          child_first_name: params[:child_first_name].to_s,
          child_last_name: params[:child_last_name].to_s,
          child_completed_grade: params[:child_completed_grade].to_s,
          t_shirt_size: params[:t_shirt_size].to_s
        }
      )
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcustomer', :error => e }.to_json
    end

    parent_name = params[:parent_first_name].to_s + ' ' + params[:parent_last_name].to_s
    child_name = params[:child_first_name].to_s + ' ' + params[:child_last_name].to_s
    begin
      description = parent_name + ' registered ' + child_name + ': ' + params[:child_completed_grade].to_s + 'yo'
      @charge = Stripe::Charge.create(
        :amount => @amount,
        :description => description,
        :currency => 'usd',
        :customer => @customer.id
      )
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcharge', :error => e }.to_json
    end

    # Log data in the database
    @record = Signup.new
    @record.email = @customer.email
    @record.parent_first_name = params[:parent_first_name]
    @record.parent_last_name = params[:parent_last_name]
    @record.child_first_name = params[:child_first_name]
    @record.child_last_name = params[:child_last_name]
    @record.child_completed_grade = params[:child_completed_grade]
    @record.child_tshirt_size = params[:t_shirt_size]
    @record.camp_selection = params[:camp_selection]
    @record.stripe_id = @customer.id
    @record.save!

    # Update class info
    @class.num_registered = @class.num_registered + 1
    @class.registered_signup_ids << @record.id
    @class.save!

    # Send a message to the customer about their registration
    send_from = 'hello@tylerpetresky.com'
    send_to = parent_name + ' <' + @customer.email + '>'
    subject = 'Thank You for Registering'

    # TODO: Need to transition this to an HTML template in the future.
    # This has to look better!
    message = 'Thank you for registering your child, ' + child_name + ', for the Oviedo Code Camp! We are very excited about meeting you. Please find below a receipt for your purchase....'
    res = Mailer.send send_from, send_to, subject, message

    # Send a message to us about a registration
    send_from = 'hello@tylerpetresky.com'
    send_to = 'Tyler Petresky <hello@tylerpetresky.com>'
    subject = '[Oviedo Code Camp] Registration'

    # Need to transition this to an HTML template in the future
    message = params[:parent_first_name] + ' ' + params[:parent_last_name] + ' has registered their child, ' + params[:child_first_name] + ' ' + params[:child_last_name] + '. They have completed the ' + params[:child_completed_grade] + 'th grade.'
    res = Mailer.send send_from, send_to, subject, message

    { :message => 'success' }.to_json
  else
    { :message => 'failure_missingparams' }.to_json
  end
end

not_found do
  File.read('templates/404.html')
end

get '/*' do
  file_name = "_site#{request.path_info}/index.html".gsub(%r{\/+},'/')
  if File.exists?(file_name)
    File.read(file_name)
  else
    raise Sinatra::NotFound
  end
end
