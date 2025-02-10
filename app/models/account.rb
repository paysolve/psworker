class Account < ApplicationRecord

    has_many :transfers

    BASIQ_ENDPOINT = "https://au-api.basiq.io" #"http://localhost:8001"
    BASIQ_SERVER_USER_ID = ENV['BASIQ_SERVER_USER_ID'] #Rails.env.development? ? "e1794628-a3e8-4485-a7b5-915902c8792d" : ENV['BASIQ_SERVER_USER_ID']
    BASIQ_SERVER_API_KEY = ENV['BASIQ_SERVER_API_KEY'] #Rails.env.development? ? "54323a86-bd4a-49f1-ae01-e2fb76b8122a" : ENV['BASIQ_SERVER_API_KEY']
    BASIQ_CONSENT_URL = "https://consent.basiq.io/home" #"https://localhost:8001/home"  

    PSMAIN_URL = Rails.env.development? ? "http://localhost:3000" : "https://www.paysolve.com.au"
    PSMAIN_TOKEN = Rails.env.development? ? 'SdD1J68HZ200RUwbbZ1OykyTwId8GBQf' : ENV['PSMAIN_TOKEN']

    GENERAL_LIMIT = 500

    INITIATED, ACTIVE, SUSPENDED, DELETED = [1,2,3,-1]

    def Account.basiq_server_auth
        if ENV['BASIQ_SERVER_TOKEN'].nil? || ENV['BASIQ_SERVER_EXPIRY'].nil? || Time.at(ENV['BASIQ_SERVER_EXPIRY'].to_i) < Time.now.to_i
            res = HTTParty.post(BASIQ_ENDPOINT+"/token",
                :headers => {'Authorization' => 'Basic '+BASIQ_SERVER_API_KEY, #Base64.strict_encode64(BASIQ_SERVER_USER_ID+':'+BASIQ_SERVER_API_KEY),
                    'Content-Type' => 'application/x-www-form-urlencoded',
                    'basiq-version' => '3.0'},
                :body => "scope=SERVER_ACCESS")
            if res.code != 200
                return false
            end
            ENV['BASIQ_SERVER_TOKEN'] = res['access_token']
            ENV['BASIQ_SERVER_EXPIRY'] = (Time.now.to_i + res['expires_in'].to_i - 5).to_s
            return res['access_token']
        else
            return ENV['BASIQ_SERVER_TOKEN']
        end
    end

    def general_save
        self.last_executed_at = 5.years.ago # 1.day.ago
        self.last_identifier = ""
        self.last_time = 5.years.ago # 1.day.ago
        self.first_identifier = ""
        self.total_transactions = 0
        self.total_transaction_value = 0
        self.last_block_transactions = 0
        self.last_block_value = 0
        return self.save
    end

    def refresh_all_connections
        res = HTTParty.post(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/connections/refresh",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        if res.code != 202
            ApplicationRecord.email_error('FAILED_REFRESH_CONNECTIONS', "Failed for Account: psmain_code: #{self['psmain_code']}, bsb: #{self['bsb']}, acct_num: #{self['account_number']}")
        end
        return res.code == 202
    end

    def transactions_until_id(limit,id)
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=#{limit}&filter=account.id.eq('#{self.account_identifier}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        txs = res['data']
        i = txs.map { |t| t['id'] }.index(id)
        return txs[0..(i-1)] if !i.nil?
        while !res['links']['next'].nil?
            res = HTTParty.get(res['links']['next']+"&limit=#{limit}",
                :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                    'Accept' => 'application/json'})
            i = res['data'].map { |t| t['id'] }.index(id)
            return txs.concat(res['data'][0..(i-1)]) if !i.nil?
            txs.concat(res['data'])
        end
        return txs
    end

    def transactions_gte_date(date,limit)
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=#{limit}&filter=account.id.eq('#{self.account_identifier}'),transaction.postDate.gteq('#{date}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        txs = res['data']
        while !res['links']['next'].nil?
            puts "Going to the next"
            res = HTTParty.get(res['links']['next']+"&limit=#{limit}",
                :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                    'Accept' => 'application/json'})
            #txs.push('.')
            txs.concat(res['data'])
        end
        return txs
    end

    def transactions_date(date,limit)
        #res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=1&filter=account.id.eq('#{self.account_identifier}'),transaction.postDate.eq('#{date}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=#{limit}&filter=account.id.eq('#{self.account_identifier}'),transaction.postDate.eq('#{date}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        txs = res['data']
        while !res['links']['next'].nil?
            res = HTTParty.get(res['links']['next']+"&limit=#{limit}",
                :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                    'Accept' => 'application/json'})
            #txs.push('.')
            txs.concat(res['data'])
        end
        return txs
    end

    def update_account_id
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/accounts",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        res['data'].each do |act|
            if self.bsb+self.account_number == act['accountNo']
                self.update_attribute(:account_identifier, act['id'])
                return true
            end
        end
        return false
    end

    def tail_alignment
        if self.last_identifier.nil?
            return self.transactions_date(Time.now.iso8601.split('T')[0],500)
        end
    end

    def alignment_since_iso8601(t)
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=#{GENERAL_LIMIT}&filter=account.id.eq('#{self.account_identifier}'),transaction.postDate.gteq('#{t}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        txs = res['data']
        while !res['links']['next'].nil?
            res = HTTParty.get(res['links']['next']+"&limit=#{GENERAL_LIMIT}",
                :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                    'Accept' => 'application/json'})
            #txs.push('.')
            txs.concat(res['data'])
        end
        return txs
    end

    def alignment_since(t)
        return self.transactions_gte_date(t.iso8601.split('T')[0], 500)
        #return nil if t > Time.now
        #tn = Time.now.iso8601.split('T')[0]
        #txs = []
        #while t.iso8601.split('T')[0] != tn
        #    txs.concat(self.transactions_date(t.iso8601.split('T')[0],500))
        #    t = t + 1.day
        #end
        #txs.concat(self.transactions_date(t.iso8601.split('T')[0],500))
        #return txs
    end

    def date_alignment(date)
        #res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/transactions?limit=1&filter=account.id.eq('#{self.account_identifier}'),transaction.postDate.eq('#{date}'),transaction.direction.eq('credit'),transaction.class.eq('transfer')",
        #    :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
        #        'Accept' => 'application/json'})
        txs = self.transactions_date(date, 500)
        return nil if txs.nil?
        ntxs = []
        txs.each do |t|
            if Transfer.find_by(identifier: t['id']).nil? && Transfer.find_by(data_digest: Transfer.data_digest(t['amount'], t['balance'], t['description'], t['reference'])).nil?
                ntxs.push(Transfer.create_from_basiq(t, self))
            end
        end
        return txs
    end

    def align_current_connection_id
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{self.user_identifier}/connections",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        return self.update_attribute(:connection_identifier, res['data'][0]['id'])
    end

    def save_txs(txs)
        txs.each do |tx|
            if Transfer.find_by(reference: Transfer.derive_reference(tx)).nil?
                ntx = Transfer.create_from_basiq(tx, self)
                if !!ntx
                    tx.merge!({code: ntx.code, created_at: ntx.created_at.iso8601})
                end
            end
        end
        return txs
    end

    def general_alignment
        return nil if !self.refresh_all_connections
        self.update_account_id
        if self.last_time.nil? # might have to think about which method to call exactly.
            txs = self.date_alignment(Time.now.iso8601.split('T')[0]) # might change this as save_txs method may be redundant here
        else
            txs = self.alignment_since_iso8601((self['last_time'] - 1.second).iso8601)
        end
        if txs.nil?
            ApplicationRecord.email_error('FAILED_RETRIEVE_TX', "Failed to retrieve transactions for Account #{self['internal_code']}")
            return nil
        end
        if txs.length > 0 && !self.send_to_psmain(txs).nil?
            self.save_txs(txs)
            self['last_executed_at'] = Time.now
            self['last_time'] = txs[0]['postDate']
            v = txs.map { |t| t['amount'].gsub('.','').to_i }.sum
            self['last_block_transactions'] = txs.length
            #self['last_block_value'] = self['last_block_value'] + v
            self['last_identifier'] = Transfer.derive_id_from_tx(txs[0])
            #self['total_transactions'] = self['total_transactions'] + txs.length
            #self['total_transaction_value'] = self['total_transaction_value'] + v
            return self.save
        else
            return nil
        end
    end

    def send_to_psmain(txs)
        res = HTTParty.post(PSMAIN_URL+"/admin/transfers",
            :headers => {'Accept' => 'application/json'},
            :body => {
                'token' => PSMAIN_TOKEN, # 'SdD1J68HZ200RUwbbZ1OykyTwId8GBQf',
                'transfers' => txs,
                'bsb' => self.bsb,
                'account_number' => self.account_number,
                'account_identifier' => self.account_identifier
            })
        if ![200,201].include?(res.code)
            ApplicationRecord.email_error('FAILED_SEND_PSMAIN', "Failed to send transactions for Account #{self['internal_code']}")
            return nil
        end
        res['transfers'].each do |tx|
            transfer = Transfer.find_by(code: tx['code'])
            if !transfer.nil?
                transfer.update_attribute(:psmain_code, tx['psmain_code'])
            end
        end
        return res['transfers'].length
    end

    def Account.account_align_from_psmain(window_minutes)
        res = HTTParty.post(PSMAIN_URL+"/admin/accountalign",
            :headers => {'Accept' => 'application/json'},
            :body => {
                'token' => PSMAIN_TOKEN,
                'window_minutes' => window_minutes
            })
        res['accounts'].each do |a|
            Account.align_from_basiq(a['user_id'], a['bsb'], a['account_number'], a['consent_id'], a['status'])
        end
    end

    def purge_day_psmain(date)
        res = HTTParty.post(PSMAIN_URL+"/admin/transfers",
            :headers => {'Accept' => 'application/json'},
            :body => {
                'date' => date,
                'bsb' => self.bsb,
                'account_number' => self.account_number,
                'account_identifier' => self.account_identifier
            })
        return nil if res.code != 201
    end

    def Account.align_from_basiq(user_id, bsb, account_number, consent_id, status)
        #return nil if !Account.find_by(bsb: bsb, account_number: account_number).nil?
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{user_id}/accounts",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        return nil if res.code != 200
        account = Account.find_by(bsb: bsb, account_number: account_number)
        acc = res['data'].filter { |a| a['bsb'] == bsb && a['unmaskedAccNum'] == account_number }[0]
        return nil if acc.nil?
        if account.nil?
            account = Account.new(
                account_identifier: acc['id'],
                institution: acc['institution'],
                bsb: acc['bsb'],
                account_number: acc['unmaskedAccNum'],
                account_name: acc['accountHolder'],
                last_executed_at: 1.year.ago,
                last_time: 1.year.ago,
                total_transactions: 0,
                total_transaction_value: 0,
                test_account: false,
                consent_identifier: consent_id,
                connection_identifier: acc['connection'],
                user_identifier: user_id,
                status: status
            )
            return account.general_save
        else
            account.assign_attributes(
                account_identifier: acc['id'],
                consent_identifier: consent_id,
                connection_identifier: acc['connection'],
                user_identifier: user_id,
                status: status
            )
            return account.save
        end
    end

    def Account.new_from_basiq(user_id, account_id)
        res = HTTParty.get(BASIQ_ENDPOINT+"/users/#{user_id}/accounts?filter=account.id.eq('#{account_id}')",
            :headers => {'Authorization' => 'Bearer '+Account.basiq_server_auth,
                'Accept' => 'application/json'})
        if res.code != 200
            return res
        end
        data = res['data'][0]
        #puts data
        #puts data['bsb']
        #puts data['accountNo']
        account = Account.find_by(bsb: data['accountNo'][0..5], account_number: data['accountNo'][6..])
        if !account.nil?
            account.update(account_identifier: data['id'], institution: data['institution'], account_name: data['accountHolder'])
            return account
        end
        account = Account.new(account_identifier: data['id'], 
            institution: data['institution'], 
            account_name: data['accountHolder'], 
            bsb: data['accountNo'][0..5], 
            account_number: data['accountNo'][6..], 
            user_identifier: user_id, 
            connection_identifier: data['connection'])
        return account
    end

    private
        def to_transact_obj(t)
            return {
                :receipt_number => t['receiptNumber'],
                :amount => t['principalAmount']['displayAmount'].tr('$.,','').to_i,
                :payment_reference_number => t['paymentReferenceNumber'],
                :transaction_time => Time.parse(t['transactionTime']).iso8601,
                :capture_time => Time.now.iso8601,
                :ps_identifiers => t['comment'].upcase.split(' '),#t['comment'].upcase.scan(PS_IDENTIFIER_REGEX),
                :status => t['status'],
                :transaction_type => t['transactionType'],
                :transaction_status => t['status']
            }
        end

        def Account.main_token
            t = Time.now.to_i.to_s
            key = Rails.env.production? ? ENV['MAIN_SERVER_KEY'] : "HMtobLp7gxEDbxIBckErxyBh5K5Phpp5"
            return [t,Digest::SHA256.base64digest(t+key)].join('.')
        end

        def Account.verify_main_server_token(token)
            t, v = token.split('.')
            key = Rails.env.production? ? ENV['WORKER_SERVER_KEY'] : "IFIeqjT73QKJNaGW7esYX0XWTHRiE2C8"
            return (t.to_i - Time.now.to_i).abs < WORKER_TOKEN_WINDOW_SECS && v == Digest::SHA256.base64digest(t+key)
        end
end
