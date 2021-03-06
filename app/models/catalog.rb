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
# == Table: catalogs
#
#  all_taxes_included :boolean          default(FALSE), not null
#  by_default         :boolean          default(FALSE), not null
#  code               :string           not null
#  created_at         :datetime         not null
#  creator_id         :integer
#  currency           :string           not null
#  description        :text
#  id                 :integer          not null, primary key
#  lock_version       :integer          default(0), not null
#  name               :string           not null
#  updated_at         :datetime         not null
#  updater_id         :integer
#  usage              :string           not null
#

class Catalog < Ekylibre::Record::Base
  refers_to :currency
  enumerize :usage, in: [:purchase, :sale, :stock, :cost], default: :sale
  # has_many :active_items, -> { where(active: true) }, class_name: "CatalogItem"
  has_many :items, class_name: 'CatalogItem', dependent: :destroy, inverse_of: :catalog
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_inclusion_of :all_taxes_included, :by_default, in: [true, false]
  validates_presence_of :code, :currency, :name, :usage
  # ]VALIDATORS]
  validates_length_of :currency, allow_nil: true, maximum: 3
  validates_length_of :code, :usage, allow_nil: true, maximum: 20
  validates_uniqueness_of :code

  selects_among_all scope: :usage

  scope :of_usage, lambda { |usage|
    where(usage: usage.to_s)
  }

  scope :for_sale, -> { of_usage(:sale).where(id: CatalogItem.select(:catalog_id)) }

  before_validation do
    self.currency ||= Preference[:currency]
    self.code = name.to_s.codeize if code.blank?
    self.code = code[0..19]
  end

  def self.by_default!(usage)
    catalog = by_default(usage)
    unless catalog
      catalog = create!(name: usage.t(scope: 'enumerize.catalog.usage'), usage: usage, by_default: true)
    end
    catalog
  end
end
