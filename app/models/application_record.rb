class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def ApplicationRecord.email_error(code, desc)
    return nil if code.nil? || desc.nil?
    res = HTTParty.post("https://emailtool.paysolve.com.au/erroralert",
      :headers => {'Content-Type' => 'application/json'},
      :body => {
        'token' => ENV['EMAIL_TOOL_KEY'],
        'code' => code,
        'description' => desc
      }.to_json)
    return res.code == 202
  end
  
end
