module Backend
  module Cells
    class AccountancyBalanceCellsController < Backend::Cells::BaseController
      def show
        f = FinancialYear.current
        if f
          f.compute_balances!
          @financial_year = f
          @started_on = f.started_on
          @stopped_on = f.stopped_on
        end
      end
    end
  end
end
