# frozen_string_literal: true

class Api::V1::Accounts::ForcePullController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:accounts' }
  before_action :require_user!
  before_action :set_account

  def show
    @accounts = account_search
    render json: @accounts, each_serializer: REST::AccountSerializer
  end

  def set_account
    @account = Account.find(params[:account_id])
  end

  private

  def account_search
    ActivityPub::ForcePullStatusesService.new.call(@account, {
      'request_id' => "#{Time.now.utc.to_i}-#{@account.username}@#{@account.domain}"
    })
  end
end
