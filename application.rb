require './helpers'
require './mailer'

before do
  content_type :json
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => ['POST'],
          'Access-Control-Allow-Headers' => ['Content-Type', 'Accept']
end

set :protection, false
set :public_dir, Proc.new { File.join(root, "_site") }

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
    'child_age',
    't_shirt_size',
    'stripeEmail',
    'stripeToken'
  ]

  if valid_params
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
        :email => params[:stripeEmail].to_s,
        :source => params[:stripeToken].to_s
      )
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcustomer', :error => e }.to_json
    end

    parent_name = params[:parent_first_name].to_s + ' ' + params[:parent_last_name].to_s
    child_name = params[:child_first_name].to_s + ' ' + params[:child_last_name].to_s
    begin

      description = parent_name + ' registered ' + child_name + ': ' + params[:child_age].to_s + 'yo'
      @charge = Stripe::Charge.create(
        :amount => @amount,
        :description => description,
        :currency => 'usd',
        :customer => @customer.id
      )
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcharge', :error => e }.to_json
    end

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
    message = params[:parent_first_name] + ' ' + params[:parent_last_name] + ' has registered their child, ' + params[:child_first_name] + ' ' + params[:child_last_name] + '. They are ' + params[:child_age] + 'years old.'
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
