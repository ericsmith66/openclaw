module NetWorth
  class TransactionsController < ApplicationController
    before_action :authenticate_user!

    def show
    end
  end
end
