module NetWorth
  class IncomeController < ApplicationController
    before_action :authenticate_user!

    def show
    end
  end
end
