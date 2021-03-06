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
# == Table: manure_management_plans
#
#  annotation                 :text
#  campaign_id                :integer          not null
#  created_at                 :datetime         not null
#  creator_id                 :integer
#  default_computation_method :string           not null
#  id                         :integer          not null, primary key
#  lock_version               :integer          default(0), not null
#  locked                     :boolean          default(FALSE), not null
#  name                       :string           not null
#  opened_at                  :datetime         not null
#  recommender_id             :integer          not null
#  selected                   :boolean          default(FALSE), not null
#  updated_at                 :datetime         not null
#  updater_id                 :integer
#
class ManureManagementPlan < Ekylibre::Record::Base
  include Attachable
  belongs_to :campaign
  belongs_to :recommender, class_name: 'Entity'
  has_many :zones, class_name: 'ManureManagementPlanZone', dependent: :destroy, inverse_of: :plan, foreign_key: :plan_id
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :opened_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_inclusion_of :locked, :selected, in: [true, false]
  validates_presence_of :campaign, :default_computation_method, :name, :opened_at, :recommender
  # ]VALIDATORS]

  accepts_nested_attributes_for :zones
  selects_among_all :selected, scope: :campaign_id

  scope :selecteds, -> { where(selected: true) }

  protect do
    locked?
  end

  after_save :compute

  def compute
    zones.map(&:compute)
  end

  def build_missing_zones
    active = false
    active = true if zones.empty?
    return false unless campaign
    campaign.activity_productions.includes(:support).order(:activity_id, 'products.name').each do |activity_production|
      # activity_production.active? return all activies except fallow_land
      next unless activity_production.support.is_a?(LandParcel) && activity_production.active?
      next if zones.find_by(activity_production: activity_production)
      zone = zones.build(
        activity_production: activity_production,
        computation_method: default_computation_method,
        administrative_area: activity_production.support.administrative_area,
        cultivation_variety: activity_production.cultivation_variety,
        soil_nature: activity_production.support.soil_nature || activity_production.support.estimated_soil_nature
      )
      zone.estimate_expected_yield
    end
  end

  def mass_density_unit
    :quintal_per_hectare
  end
end
