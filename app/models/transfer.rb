class Transfer < ApplicationRecord
  belongs_to :account

  def Transfer.create_from_basiq(h, account)
    puts 'a'
    transfer = account.transfers.build(posted_date: h['postDate'].split('T')[0], posted_datetime: h['postDate'], identifier: h['id'], connection_identifier: h['connection'], reference: h['reference'].nil? || h['reference'].length == 0 ? nil : Transfer.derive_reference(h))
    puts 'b'
    transfer['data_digest'] = Transfer.data_digest(h['amount'], h['balance'], h['description'], h['reference'])
    return transfer if !!transfer.general_save
  end

  def Transfer.data_digest(amt, bal, desc, ref)
    Digest::SHA256.hexdigest([ref,amt,desc,bal].join(':'))
  end

  def Transfer.derive_reference(tx)
    tx['institution']+':'+tx['reference']
  end

  def Transfer.derive_id_from_tx(tx)
    tx['reference'].nil? || tx['reference'].length == 0 ? tx['id'] : Transfer.derive_reference(tx)
  end

  def general_save
    self.code = "PWT_"+SecureRandom.alphanumeric(10).upcase
    return self.save
  end
end
