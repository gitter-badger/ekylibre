# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2016 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: incoming_payments
#
#  accounted_at          :datetime
#  affair_id             :integer
#  amount                :decimal(19, 4)   not null
#  bank_account_number   :string
#  bank_check_number     :string
#  bank_name             :string
#  commission_account_id :integer
#  commission_amount     :decimal(19, 4)   default(0.0), not null
#  created_at            :datetime         not null
#  creator_id            :integer
#  currency              :string           not null
#  custom_fields         :jsonb
#  deposit_id            :integer
#  downpayment           :boolean          default(TRUE), not null
#  id                    :integer          not null, primary key
#  journal_entry_id      :integer
#  lock_version          :integer          default(0), not null
#  mode_id               :integer          not null
#  number                :string
#  paid_at               :datetime
#  payer_id              :integer
#  receipt               :text
#  received              :boolean          default(TRUE), not null
#  responsible_id        :integer
#  scheduled             :boolean          default(FALSE), not null
#  to_bank_at            :datetime         not null
#  updated_at            :datetime         not null
#  updater_id            :integer
#

require 'test_helper'

class IncomingPaymentTest < ActiveSupport::TestCase
  test 'the bookkeeping of a payment' do
    payment = incoming_payments(:incoming_payments_001)
    payment.bookkeep(:create)
    assert_not_nil payment.journal_entry
    assert_equal payment.amount, payment.journal_entry.real_debit
    assert_equal payment.amount, payment.journal_entry.real_credit
  end
end
