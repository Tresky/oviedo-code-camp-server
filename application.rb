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

post '/signup' do
  puts 'Signup Endpoint'
  @amount = 35000

  valid_params = Helpers.pull_params params, [
    'parent_name',
    'child_name',
    'child_age',
    'email',
    'tshirt_size',
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
      puts 'Email: ' + params[:email]
      puts 'Stripe: ' + params[:stripeToken]
      @customer = Stripe::Customer.create(
        :email => params[:email].to_s,
        :source => params[:stripeToken].to_s
      )

      puts 'Customer: ' + @customer.id
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcustomer', :error => e }.to_json
    end

    begin
      @charge = Stripe::Charge.create(
        :amount => @amount,
        :description => params[:parent_name] + ' registered ' + params[:child_name] + ': ' + params[:child_age] + 'yo',
        :currency => 'usd',
        :customer => @customer.id
      )

      puts 'Charge: ' + @charge.id
    rescue Stripe::StripeError => e
      return { :message => 'failure_creatingcharge', :error => e }.to_json
    end

    message = params[:parent_name] + ' has registered their child, ' + params[:child_name] + '. They are ' + params[:child_age] + 'years old.',
    res = Mailer.send 'hello@tylerpetresky.com', 'Tyler Petresky <hello@tylerpetresky.com>', '[Oviedo Code Camp] Registration', message

    {:message => 'success' }.to_json
  else
    { :message => 'failure_missingparams' }.to_json
  end
end

not_found do
  File.read('_site/404.html')
end

get '/*' do
  file_name = "_site#{request.path_info}/index.html".gsub(%r{\/+},'/')
  if File.exists?(file_name)
    File.read(file_name)
  else
    raise Sinatra::NotFound
  end
end
