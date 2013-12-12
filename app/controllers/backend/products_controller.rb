# -*- coding: utf-8 -*-
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::ProductsController < BackendController
  manage_restfully t3e: {nature_name: :nature_name}, subclass_inheritance: true
  manage_restfully_picture

  respond_to :pdf, :odt, :docx, :xml, :json, :html, :csv

  before_action :check_variant_availability, only: :new

  unroll

  list do |t|
    t.column :number, url: true
    t.column :name, url: true
    t.column :variant, url: true
    t.column :variety
    t.column :container, url: true
    t.column :description
    t.action :show, url: {:format => :pdf}, image: :print
    t.action :edit
    t.action :destroy, :if => :destroyable?
  end

  # content product list of the consider product
  list(:contained_products, model: :product_localizations, conditions: {container_id: 'params[:id]'.c}, order: {started_at: :desc}) do |t|
    t.column :product, url: true
    t.column :nature
    t.column :intervention, url: true
    t.column :started_at
    t.column :arrival_cause, hidden: true
    t.column :stopped_at
    t.column :departure_cause, hidden: true
  end

  # localization of the consider product
  list(:places, model: :product_localizations, conditions: {product_id: 'params[:id]'.c}, order: {started_at: :desc}) do |t|
    t.column :nature
    t.column :container, url: true
    t.column :intervention, url: true
    t.column :started_at
    t.column :arrival_cause, hidden: true
    t.column :stopped_at, hidden: true
    t.column :departure_cause, hidden: true
  end

  list(:carried_linkages, model: :product_linkages, conditions: {carrier_id: 'params[:id]'.c}, order: {started_at: :desc}) do |t|
    t.column :carried, url: true
    t.column :point
    t.column :nature
    t.column :intervention, url: true
    t.column :started_at, through: :intervention
    t.column :stopped_at, through: :intervention
  end

  list(:carrier_linkages, model: :product_linkages, conditions: {carried_id: 'params[:id]'.c}, order: {started_at: :desc}) do |t|
    t.column :carrier, url: true
    t.column :point
    t.column :nature
    t.column :intervention, url: true
    t.column :started_at
    t.column :stopped_at
  end

  # groups of the consider product
  list(:groups, model: :product_memberships, conditions: {member_id: 'params[:id]'.c}, order: {started_at: :desc}) do |t|
    t.column :group, url: true
    t.column :intervention, url: true
    t.column :started_at
    t.column :stopped_at
  end

  # members of the consider product
  list(:members, model: :product_memberships, conditions: {group_id: 'params[:id]'.c}, order: :started_at) do |t|
    t.column :member, url: true
    t.column :intervention, url: true
    t.column :started_at
    t.column :stopped_at
  end

  # indicators of the consider product
  list(:indicators, model: :product_indicator_data, conditions: {product_id: 'params[:id]'.c}, order: {created_at: :desc}) do |t|
    t.column :indicator_name
    t.column :measured_at
    t.column :value
  end

  # incidents of the consider product
  list(:incidents, conditions: {target_id: 'params[:id]'.c, target_type: 'controller_name.classify.constantize'.c}, order: {observed_at: :desc}) do |t|
    t.column :name, url: true
    t.column :nature
    t.column :observed_at
    t.column :gravity
    t.column :priority
    t.column :state
  end

  # incidents of the consider product
  list(:intervention_casts, conditions: {actor_id: 'params[:id]'.c}) do |t|
    t.column :intervention, url: true
    t.column :roles
    t.column :name, sort: :reference_name
    t.column :started_at, through: :intervention
    t.column :stopped_at, through: :intervention
  end

  # List supports for one production
  list(:markers, model: :production_support_markers, order: {created_at: :desc}) do |t|
    t.column :production_name, through: :support, url: true
    t.column :indicator_name
    t.column :value
    t.column :started_at
    t.column :stopped_at
  end

  protected

  def check_variant_availability()
    unless ProductNatureVariant.of_variety(controller_name.to_s.underscore.singularize).any?
      redirect_to new_backend_product_nature_url
      return false
    end
  end


end