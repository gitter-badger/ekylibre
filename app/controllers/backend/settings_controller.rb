# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
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
  class SettingsController < Backend::BaseController
    def edit
      Preference.check!
    end

    def update
      saved = true
      ActiveRecord::Base.transaction do
        for key, data in params[:preferences]
          preference = Preference.get!(key)
          if preference
            preference.value = data[:value]
            preference.save
          else
            saved = false
          end
        end
      end
      redirect_to_back && return if saved
      render :edit
    end

    def about
      @properties = []
      @properties.insert(0, ['Ekylibre version', Ekylibre.version])
      @properties << ['Database version', ActiveRecord::Migrator.current_version]
    end
  end
end
