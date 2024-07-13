class AccountsController < ApplicationController

    EXTERNAL_TOKEN_DIGEST = Rails.env.development? ? "61353137b1a16f896c80b8997b516819d164a0a599c7336c3b9938be38e112fa" : ENV['EXTERNAL_TOKEN_DIGEST']

    def test_create_payments
        if Account.verify_main_server_token(params[:token])
            account = Account.find_by(internal_code: params[:account_internal_code])
            params[:invoices].each do |invobj|
                account.test_create_payment(invobj[:ps_identifier], invobj[:amount])
            end
        else
            render plain: {error: 'Incorrect token.'}.to_json, status: 400
        end
    end

    def create_account
        
    end
end
