class Disbursement < ApplicationRecord
  belongs_to :account
  has_many :outlays

  # Statuses
  # 0 - uninitialised
  UNINITIALISED = 0
  # 1 - collecting payments
  COLLECTING_PAYMENTS = 1
  # 2 - finished collecting payments
  FINISHED_COLLECTION = 2
  # 3 - file created successfully
  FILE_CREATED = 3
  # 4 - payment acceptance closed, all payments added successfully
  PAYMENTS_ADDED = 4
  # 5 - file sent for processing
  FILE_SENT_PROCESSING = 5
  # 6 - payments submitted to bank for processing
  PAYMENTS_SUBMITTED = 6
  # 7 - payments complete
  PAYMENT_COMPLETE = 7
  # -1 - error was found
  ERROR_FOUND = -1
  # -2 - NEEDS ATTENTION
  NEEDS_ATTENTION = -2

  def generate_paymentsplus_file
    #records = Outlay.where(status:1,disbursement_id:self.id).map { |o| o.generate_westpac_record }
    outlays = Outlay.where(status: 1, disbursement_id: self.id)
    return [self.header_record, outlays.map { |o| o.generate_westpac_record }, self.trailer_record(outlays.count, outlays.map { |o| o.amount }.sum)].flatten.join("\n")#.flatten.map { |l| l.map { |i| '"'+i.to_s+'"' }.join(',') }.join('\n')
  end

  def header_record
    return [
      'H',
      self.account.outlay_username,
      self.account.outlay_name,
      self.code,
      Time.now.iso8601[0..9].split('-').reverse.join(''),
      'AUD',
      '5'
    ].map { |i| '"'+i.to_s+'"' }.join(',')
  end

  def trailer_record(payment_count, amount_total)
    return [
      'T',
      payment_count,
      [amount_total.to_s[..-3],amount_total.to_s[-2..]].join('.')
    ].map { |i| '"'+i.to_s+'"' }.join(',')
  end

  def general_create
    self.code = SecureRandom.alphanumeric
    self.status = COLLECTING_PAYMENTS
    return self.save
  end

  def Disbursement.test_create(account, num_outlays)
    disbursement = Disbursement.new
    disbursement.account_id = account.id
    disbursement.general_create
    num_outlays.times do
      outlay = Outlay.new
      outlay.test_populate(disbursement)
    end
    disbursement.update_attribute(:total_amount, disbursement.outlays.map { |o| o.amount }.sum)
    return disbursement
  end

  def create_paymentsplus_file
    res = HTTParty.put("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}",
      :headers => {
        'Authorization'=>'Basic '+self.account.outlay_auth,
        'Content-Type'=>'application/json'
      },
      :body => {
        'fileName'=>self.code+'.csv',
        'paymentDate'=>Date.tomorrow.iso8601,
        'referenceCode'=>self.code
      }.to_json)
    if res.code == 200
      self.update_attribute(:status, FILE_CREATED)
    end
    return res
  end

  def get_paymentsplus_file_payments
    res = HTTParty.get("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}/payments",
      :headers => {
        'Authorization'=>'Basic '+self.account.outlay_auth
      })
    return res
  end

  def add_all_payments_to_file
    self.outlays.each do |outlay|
      if outlay.status == COLLECTING_PAYMENTS
        outlay.add_payment_to_file
      end
    end
  end

  def send_file_for_processing
    if self.status != PAYMENTS_ADDED
      return nil
    end
    res = HTTParty.post("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}/send",
      :headers => {
        'Authorization'=>'Basic '+self.account.outlay_auth
      })
    if [200,201].include?(res.code)
      self.update_attribute(:status, FILE_SENT_PROCESSING)
    end
    return res
  end

  def get_payments_file
    if self.status < FINISHED_COLLECTION
      return nil
    end
    res = HTTParty.get("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}",
      :headers => {
        'Authorization'=>'Basic '+self.account.outlay_auth
      })
    if [200,201].include?(res.code)
      statuses = {'OPEN'=>FINISHED_COLLECTION,'PENDING'=>FILE_SENT_PROCESSING,'FORMAT_CHECK'=>FILE_SENT_PROCESSING,'VALIDATED'=>FILE_SENT_PROCESSING,'ERROR'=>ERROR_FOUND,'AUTHORISATION_REQUIRED'=>NEEDS_ATTENTION,'SECOND_AUTH_REQUIRED'=>NEEDS_ATTENTION,'CANCELLED'=>0,'PROCESSING'=>PAYMENTS_SUBMITTED,'COMPLETE'=>PAYMENT_COMPLETE,'POSSIBLE_DUPLICATE'=>NEEDS_ATTENTION}
      if statuses.include?(res['statusCode'])
        self.update_attribute(:status, statuses[res['statusCode']])
      end
    end
    return res
  end

  def create_and_upload_westpac_file
    #res = HTTParty.post("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}/upload",
    #        :headers => {
    #            'Authorization' => 'Basic ' + self.account.outlay_auth,
    #            'Content-Type' => "multipart/form-data",
    #           'Prevent-CSRF' => 'true'
    #       },
    #        :body => {
    #            'file'=>self.generate_paymentsplus_file
    #        }.to_json)
    #return res
    filedata = self.generate_paymentsplus_file
    File.open(self.code+'.csv','w') { |f| f.write(filedata) }
    res = RestClient::Request.execute(
      method: :post,
      url: "https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.code}/upload",
      payload: File.open(self.code+'.csv','r'),
      headers: {
        'Content-Type'=>'multipart/form-data',
        'Authorization'=>'Basic '+self.account.outlay_auth
      },
      body: {
        file: self.code+'.csv'
      }.to_json
    )
    return res
  end
end
