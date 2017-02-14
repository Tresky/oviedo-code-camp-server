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
  body = 'secret=6LdZXBUUAAAAAIDdtkCWTDS2Ca7RgkcizUgUYq6U&response=' + params['g-recaptcha-response']
  puts body
  response = HTTParty.post('https://www.google.com/recaptcha/api/siteverify',
    :body => body,
    :headers => {
      'Content-Type' => 'application/x-www-form-urlencoded;charset=utf-8'
    })

  puts 'ReCaptcha Result'
  puts response

  if response['success']
    res = Pony.mail(
      :from => params[:name] + "<" + params[:email] + ">",
      :to => 'hello@tylerpetresky.com',
      :subject => "[OVIEDO CODE CAMP] Contact Form",# + params[:subject],
      :body => params[:message],
      :via => :smtp,
      :via_options => {
        :address              => 'smtp.sendgrid.net',
        :port                 => '587',
        :enable_starttls_auto => true,
        :user_name            => ENV['SENDGRID_USERNAME'],
        :password             => ENV['SENDGRID_PASSWORD'],
        :authentication       => :plain,
        :domain               => 'heroku.com'
      })
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
