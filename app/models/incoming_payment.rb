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

class IncomingPayment < Ekylibre::Record::Base
  include PeriodicCalculable, Attachable
  include Customizable
  attr_readonly :payer_id
  attr_readonly :amount, :account_number, :bank, :bank_check_number, :mode_id, if: proc { deposit && deposit.locked? }
  refers_to :currency
  belongs_to :commission_account, class_name: 'Account'
  belongs_to :responsible, class_name: 'User'
  belongs_to :deposit, inverse_of: :payments
  belongs_to :journal_entry
  belongs_to :payer, class_name: 'Entity', inverse_of: :incoming_payments
  belongs_to :mode, class_name: 'IncomingPaymentMode', inverse_of: :payments
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :accounted_at, :paid_at, :to_bank_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_numericality_of :amount, :commission_amount, allow_nil: true
  validates_inclusion_of :downpayment, :received, :scheduled, in: [true, false]
  validates_presence_of :amount, :commission_amount, :currency, :mode, :to_bank_at
  # ]VALIDATORS]
  validates_length_of :currency, allow_nil: true, maximum: 3
  validates_numericality_of :amount, greater_than: 0.0
  validates_numericality_of :commission_amount, greater_than_or_equal_to: 0.0
  validates_presence_of :payer
  validates_presence_of :commission_account, if: :with_commission?

  delegate :status, to: :affair

  acts_as_numbered
  acts_as_affairable :payer, dealt_at: :to_bank_at, role: 'client'

  scope :depositables, -> { where("deposit_id IS NULL AND to_bank_at <= ? AND mode_id IN (SELECT id FROM #{IncomingPaymentMode.table_name} WHERE with_deposit = ?)", Time.zone.now, true) }

  scope :depositables_for, lambda { |deposit, mode = nil|
    deposit = Deposit.find(deposit) unless deposit.is_a?(Deposit)
    where('to_bank_at <= ?', Time.zone.now).where('deposit_id = ? OR (deposit_id IS NULL AND mode_id = ?)', deposit.id, (mode ? mode_id : deposit.mode_id))
  }
  scope :last_updateds, -> { order(updated_at: :desc) }

  scope :between, lambda { |started_at, stopped_at|
    where(paid_at: started_at..stopped_at)
  }

  calculable period: :month, column: :amount, at: :paid_at, name: :sum

  before_validation(on: :create) do
    self.to_bank_at ||= Time.zone.now
    self.scheduled = (self.to_bank_at > Time.zone.now ? true : false)
    self.received = false if scheduled
    true
  end

  before_validation do
    if self.mode
      self.commission_account ||= self.mode.commission_account
      self.commission_amount ||= self.mode.commission_amount(amount)
      self.currency = self.mode.currency
    end
    true
  end

  validate do
    if self.mode
      errors.add(:currency, :invalid) if currency != self.mode.currency
      if self.deposit
        errors.add(:deposit_id, :invalid) if mode_id != self.deposit.mode_id
      end
    end
  end

  protect(on: :update) do
    (self.deposit && self.deposit.protected_on_update?) || (journal_entry && journal_entry.closed?)
  end

  # This method permits to add journal entries corresponding to the payment
  # It depends on the preference which permit to activate the "automatic bookkeeping"
  bookkeep do |b|
    mode = self.mode
    label = tc(:bookkeep, resource: self.class.model_name.human, number: number, payer: payer.full_name, mode: mode.name, check_number: bank_check_number)
    if mode.with_deposit?
      b.journal_entry(mode.depositables_journal, printed_on: self.to_bank_at.to_date, unless: (!mode || !mode.with_accounting? || !received)) do |entry|
        entry.add_debit(label,  mode.depositables_account_id, amount - self.commission_amount)
        entry.add_debit(label,  commission_account_id, self.commission_amount) if self.commission_amount > 0
        entry.add_credit(label, payer.account(:client).id, amount) unless amount.zero?
      end
    else
      b.journal_entry(mode.cash_journal, printed_on: self.to_bank_at.to_date, unless: (!mode || !mode.with_accounting? || !received)) do |entry|
        entry.add_debit(label,  mode.cash.account_id, amount - self.commission_amount)
        entry.add_debit(label,  commission_account_id, self.commission_amount) if self.commission_amount > 0
        entry.add_credit(label, payer.account(:client).id, amount) unless amount.zero?
      end
    end
  end

  # Returns true if payment is already deposited
  def deposited?
    !!deposit
  end
  alias deposit? deposited?

  # Returns if a commission is taken
  def with_commission?
    mode && mode.with_commission?
  end

  # Build and return a label for the payment
  def label
    tc(:label, amount: amount.l(currency: mode.cash.currency), date: self.to_bank_at.l, mode: mode.name, payer: payer.full_name, number: number)
  end
end
