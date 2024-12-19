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
        if Digest::SHA256.hexdigest(params[:token]) != EXTERNAL_TOKEN_DIGEST
            render json: {error: "Forbidden"}.to_json, status: 401
            return nil
        end
        # Create account from psmain here
    end

    def create_account_from_psmain
        if Digest::SHA256.hexdigest(params[:token]) != EXTERNAL_TOKEN_DIGEST
            render json: {error: "Forbidden"}.to_json, status: 401
            return nil
        end
        #account = Account.new_from_basiq(params[:user_id], params[:account_id])
        if params[:status].to_i != Account::ACTIVE
            account = Account.find_by(bsb: params[:bsb], account_number: params[:account_number])
            account.update(status: params[:status].to_i) if !account.nil?
            render json: {
                success: true
            }.to_json
        end
        #Account.create_account_from_psmain(params[:user_id], params[:bsb], params[:account_number], params[:consent_id], params[:status])
        render json: {
            success: !!Account.align_from_basiq(params[:user_id], params[:bsb], params[:account_number], params[:consent_id], params[:status])
        }.to_json
        #if !!account.general_save
        #    render json: {
        #        success: true,
        #        id: account.id
        #    }.to_json, status: 201
        #else
        #    render json: {
        #        success: true
        #    }.to_json
        #end
    end

    def update_api
        if Digest::SHA256.hexdigest(params[:token]) != EXTERNAL_TOKEN_DIGEST
            render json: {error: "Forbidden"}.to_json, status: 401
            return nil
        end
        if !!params[:exec_all]
            Account.where("account_identifier is not null").each do |account|
                account.general_alignment
            end
        else
            params[:account_codes].each do |account_code|
                account = Account.find_by(psmain_code: account_code)
                if !account.nil?
                    account.general_alignment
                end
            end
        end
        render json: {
            success: true
        }.to_json, status: 200
    end
end
