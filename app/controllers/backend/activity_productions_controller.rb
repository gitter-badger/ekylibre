# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2013 David Joulin, Brice Texier
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class ActivityProductionsController < Backend::BaseController
    manage_restfully(t3e: { name: :name }, creation_t3e: true, except: :index)

    unroll :rank_number, activity: :name, support: :name

    def index
      @activities = Activity.of_campaign(current_campaign).order(name: :asc) || []
    end

    # List interventions for one production support
    list(:interventions, conditions: "['interventions.id IN (SELECT intervention_id FROM intervention_parameters WHERE type = \\'InterventionTarget\\' AND product_id IN (SELECT target_id FROM target_distributions WHERE activity_production_id = ?))', params[:id]]".c, order: { created_at: :desc }, line_class: :status) do |t|
      t.column :name, url: true
      # t.status
      t.column :started_at
      t.column :human_working_duration
      t.column :human_target_names
      t.column :human_working_zone_area
      t.column :stopped_at, hidden: true
      t.column :issue, url: true
      # t.column :provisional
    end
  end
end
