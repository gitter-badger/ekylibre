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
# == Table: catalog_items
#
#  all_taxes_included     :boolean          default(FALSE), not null
#  amount                 :decimal(19, 4)   not null
#  catalog_id             :integer          not null
#  commercial_description :text
#  commercial_name        :string
#  created_at             :datetime         not null
#  creator_id             :integer
#  currency               :string           not null
#  id                     :integer          not null, primary key
#  lock_version           :integer          default(0), not null
#  name                   :string           not null
#  reference_tax_id       :integer
#  updated_at             :datetime         not null
#  updater_id             :integer
#  variant_id             :integer          not null
#

# CatalogItem stores all the prices used in sales and purchases.
class CatalogItem < Ekylibre::Record::Base
  refers_to :currency
  belongs_to :variant, class_name: 'ProductNatureVariant'
  belongs_to :reference_tax, class_name: 'Tax'
  belongs_to :catalog
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_numericality_of :amount, allow_nil: true
  validates_inclusion_of :all_taxes_included, in: [true, false]
  validates_presence_of :amount, :catalog, :currency, :name, :variant
  # ]VALIDATORS]
  validates_length_of :currency, allow_nil: true, maximum: 3
  validates_uniqueness_of :variant_id, scope: :catalog_id

  # delegate :product_nature_id, :product_nature, to: :template
  delegate :name, to: :variant, prefix: true
  delegate :unit_name, to: :variant
  delegate :usage, :all_taxes_included?, to: :catalog

  scope :of_variant, lambda { |variant|
    where(variant_id: variant.id)
  }

  scope :of_usage, lambda { |usage|
    joins(:catalog).merge(Catalog.of_usage(usage))
  }

  scope :saleables, lambda {
    joins(variant: :category).where(product_nature_categories: { saleable: true })
  }

  before_validation on: :create do
    self.currency = Preference[:currency] if currency.blank?
  end

  before_validation do
    self.amount = amount.round(4) if amount
    self.name = commercial_name
    self.name = variant_name if commercial_name.blank? && self.variant
  end

  # Compute a pre-tax amount
  def pretax_amount
    (all_taxes_included? ? reference_tax.pretax_amount_of(amount) : amount)
  end
  alias unit_pretax_amount pretax_amount
end
