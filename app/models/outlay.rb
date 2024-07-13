class Outlay < ApplicationRecord
  belongs_to :disbursement, optional: true

  # 0 - uninitialised
  # 1 - created and attached to a disbursement
  # 2 - uploaded to a payment file
  # 3 - payment file sent
  # 4 - payment executed
  # 5 - payment failed, retry
  # 6 - payment failed, flag

  def generate_westpac_osko_record # test!
    return [
      'O',
      nil,
      self.code,
      [self.amount.to_s[..-3],self.amount.to_s[-2..]].join('.'),
      nil,
      (self.bsb+self.account_number).gsub(' ',''),
      "BBAN",
      self.account_name,
      nil,nil,nil,nil
    ].map { |i| '"'+i.to_s+'"' }.join(',')
  end

  def generate_westpac_eft_record
    return [
      'E',
      nil,
      self.code,
      [self.amount.to_s[..-3],self.amount.to_s[-2..]].join('.'),
      self.code,
      self.bsb[0..2]+'-'+self.bsb[3..5],
      self.account_number.gsub(' ',''),
      self.account_name,
      nil,nil
    ].map { |i| '"'+i.to_s+'"' }.join(',')
  end
  
  def generate_westpac_record
    self.can_use_osko? ? self.generate_westpac_osko_record : self.generate_westpac_eft_record
  end

  def general_create
    self.code = SecureRandom.alphanumeric
    return self.save
  end

  def can_use_osko?
    osko = ["AMP","ADC","ANZ","BQL","BYB","BBL","CFC","CNA","CBA","CUA","DBL","GCB","GBS","HBS","HCC","HUM","IMB","ING","GNI","MMP","BAU","NAB","PCU","QCB","RCU","RAB","ROK","SKY","MET","WBC","YOU"] 
    return osko.include?(BSB.lookup(self.bsb)[:mnemonic])
  end

  def test_populate(disbursement)
    self.amount = (SecureRandom.rand * 100000).to_i
    #self.bsb = ['062020','062217','062692','062799','062948','063599','066132','066161','062202','065126']
    self.bsb = ['062020','062217','062692','062799','062948','063599','066132','066161','062202','065126','014001','014002'].sample
    self.account_name = [['Alan','Bob','Calvin','Darryl','Edgar','Frederick','Guilford','Harold','Ian','John'].sample,['Johnson','Smith','Chambers','Fuentes','Abbott','Miller','Thomas'].sample].join(' ')
    self.account_number = (SecureRandom.rand*90000000+10000000).to_i.to_s
    self.status = 1
    self.purpose = 1
    self.payment_type = 2
    self.disbursement_id = disbursement.id
    return self.general_create
  end

  def add_payment_to_file
    if self.status >= 2
      return nil
    end
    res = HTTParty.put("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.disbursement.code}/payments/#{self.code}",
      :headers => {
        'Authorization'=>'Basic '+self.disbursement.account.outlay_auth,
        'Content-Type'=>'application/json'
      },
      :body => {
        'paymentMethod'=>'DIRECT_ENTRY', # need to see if we can get OSKO - talk to Westpac
        'paymentAmount'=>[self.amount.to_s[..-3],self.amount.to_s[-2..]].join('.'),
        'paymentDate'=>Date.tomorrow.iso8601,
        'recipientAccount'=>{
          'type'=>'AU_DOMESTIC',
          'accountName'=>self.account_name,
          'bsbNumber'=>self.bsb,
          'accountNumber'=>self.account_number
        },
        'payeeName'=>self.account_name,
        'currency'=>'AUD',
        'lodgementReference'=>self.code,
        'paymentReference'=>'PaySolve '+self.code
      }.to_json)
    if [200,201].include?(res.code)
      self.update_attribute(:status, 2)
    end
    return res
  end

  def cancel_payment_in_file
    if self.status != 2
      return nil
    end
    res = HTTParty.post("https://api.paymentsplus.support.qvalent.com/rest/v1/files/#{self.disbursement.code}/payments/#{self.code}/cancel",
      :headers => {
        'Authorization'=>'Basic '+self.disbursement.account.outlay_auth,
        'Content-Type'=>'application/json'
      })
    if [200,201].include?(res.code)
      self.update_attribute(:status, 1)
    end
    return res
  end
end
