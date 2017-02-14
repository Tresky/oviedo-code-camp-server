class Mailer
  def Mailer.send(from, to, subject, message)
    res = Pony.mail(
      :from => from.to_s,
      :to => to.to_s,
      :subject => subject.to_s,
      :body => message.to_s,
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
    res
  end
end
