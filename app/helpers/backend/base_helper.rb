# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2013 Brice Texier
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
  module BaseHelper
    def resource
      instance_variable_get('@' + controller_name.singularize)
    end

    def resource_model
      controller_name.classify.constantize
    end

    def collection
      instance_variable_get('@' + controller_name)
    end

    def historic_of(record = nil)
      record ||= resource
      render(partial: 'backend/shared/historic', locals: { resource: resource })
    end

    def root_models
      Ekylibre::Schema.models.collect { |a| [Ekylibre::Record.human_name(a.to_s.singularize), a.to_s.singularize] }.sort { |a, b| a[0].ascii <=> b[0].ascii }
    end

    def navigation_tag
      render(partial: 'layouts/navigation')
    end

    # It's the menu generated for the current user
    # Therefore: No current user => No menu
    def menus
      Ekylibre.menu
    end

    # BasicCalendar permits to fix some SimpleCalendar issues with param name
    # and partial.
    class BasicCalendar < SimpleCalendar::MonthCalendar
      # Overwrite default partial name
      def partial_name
        @options[:partial] || 'backend/shared/month_calendar'
      end

      def date_param_name
        @options[:param_name] ||= :start_date
      end

      def start_date
        view_context.params.fetch(date_param_name, Date.today).to_date
      end
    end

    # Emulate old simple_calendar API
    def basic_calendar(all_records, options = {}, &block)
      # options[:events] = all_records
      options[:param_name] ||= :started_on
      BasicCalendar.new(self, options).render do |event_on, records|
        records = all_records.select do |event|
          event_on == event.started_at.to_date
        end
        content_tag(:div) do
          content_tag(:span, event_on.day, class: 'day-number') +
            records.collect do |event|
              capture(event, &block)
            end.join.html_safe
        end
      end
    end

    def part_authorized?(part)
      part.children.each do |group|
        group.children.each do |item|
          return true if authorized?(item.default_page.to_hash)
        end
      end
      false
    end

    def side_tag
      render(partial: 'layouts/side')
    end

    def add_snippets(place, _options = {})
      Ekylibre::Snippet.at(place).each do |s|
        snippet(s.name, { icon: :plug }.merge(s.options)) do
          render(file: s.path)
        end
      end
    end

    def side_menu(*args, &_block)
      return '' unless block_given?
      main_options = (args[-1].is_a?(Hash) ? args.delete_at(-1) : {})
      menu = Menu.new
      yield menu

      main_name = args[0].to_s.to_sym
      main_options[:icon] ||= main_name.to_s.parameterize.tr('_', '-')

      html = ''.html_safe
      for name, url, options in menu.items
        li_options = {}
        li_options[:class] = 'active' if options.delete(:active)

        kontroller = (url.is_a?(Hash) ? url[:controller] : nil) || controller_name
        options[:title] ||= ::I18n.t("actions.#{kontroller}.#{name}".to_sym, { default: ["labels.#{name}".to_sym] }.merge(options.delete(:i18n) || {}))
        if icon = options.delete(:icon)
          item[:title] = content_tag(:i, '', class: 'icon-' + icon.to_s) + ' '.html_safe + h(item[:title])
        end
        url[:action] ||= name if name != :back && url.is_a?(Hash)
        html << content_tag(:li, link_to(options[:title], url, options), li_options) if authorized?(url)
      end

      unless html.blank?
        html = content_tag(:ul, html)
        snippet(main_name, main_options) { html }
      end

      nil
    end

    class Menu
      attr_reader :items

      def initialize
        @items = []
      end

      def link(name, url = {}, options = {})
        @items << [name, url, options]
      end
    end

    def snippet(name, options = {}, &block)
      collapsed = current_user.preference("interface.snippets.#{name}.collapsed", false, :boolean).value
      collapsed = false if collapsed && options[:title].is_a?(FalseClass)

      options[:class] ||= ''
      options[:icon] ||= name
      options[:class] << " snippet-#{options[:icon]}"
      options[:class] << ' active' if options[:active]

      html = ''
      html << "<div id='#{name}' class='snippet#{' ' + options[:class].to_s if options[:class]}#{' collapsed' if collapsed}'>"

      unless options[:title].is_a?(FalseClass)
        html << "<a href='#{url_for(controller: '/backend/snippets', action: :toggle, id: name)}' class='snippet-title' data-toggle-snippet='true'>"
        html << "<i class='collapser'></i>"
        html << '<h3><i></i>' + (options[:title] || "snippets.#{name}".t(default: ["labels.#{name}".to_sym])) + '</h3>'
        html << '</a>'
      end

      html << "<div class='snippet-content'" + (collapsed ? ' style="display: none"' : '') + '>'
      begin
        html << capture(&block)
      rescue Exception => e
        html << content_tag(:small, "#{e.class.name}: #{e.message}")
      end
      html << '</div>'

      html << '</div>'
      content_for(:aside, html.html_safe)
      nil
    end

    def variable_readings(resource)
      indicators = resource.variable_indicators.delete_if { |i| ![:measure, :decimal].include?(i.datatype) }
      series = []
      now = (Time.zone.now + 7.days)
      window = 1.day
      min = (resource.born_at ? resource.born_at : now - window)
      min = now - window if (now - min) < window
      for indicator in indicators # [:population, :nitrogen_concentration].collect{|i| Nomen::Indicator[i] }
        items = ProductReading.where(indicator_name: indicator.name, product: resource).where('? < read_at AND read_at < ?', min, now).order(:read_at)
        next unless items.any?
        data = []
        data << [min.to_usec, resource.get(indicator, at: min).to_d.to_s.to_f]
        data += items.inject({}) do |hash, pair|
          hash[pair.read_at.to_usec] = pair.value.to_d
          hash
        end.collect { |k, v| [k, v.to_s.to_f] }
        data << [now.to_usec, resource.get(indicator, at: now).to_d.to_s.to_f]
        series << { name: indicator.human_name, data: data, step: 'left' }
      end
      return no_data if series.empty?

      line_highcharts(series, legend: {}, y_axis: { title: { text: :indicator.tl } }, x_axis: { type: 'datetime', title: { enabled: true, text: :months.tl }, min: min.to_usec })
    end

    def main_campaign_selector
      content_for(:heading_toolbar) do
        campaign_selector
      end
    end

    def campaign_selector(campaign = nil, options = {})
      unless Campaign.any?
        @current_campaign = Campaign.find_or_create_by!(harvest_year: Date.current.year)
        current_user.current_campaign = @current_campaign
      end
      campaign ||= current_campaign
      render 'backend/shared/campaign_selector', campaign: campaign, param_name: options[:param_name] || :current_campaign_id
    end

    def lights(status, html_options = {})
      if html_options.key?(:class)
        html_options[:class] << " lights lights-#{status}"
      else
        html_options[:class] = "lights lights-#{status}"
      end
      content_tag(:span, html_options) do
        content_tag(:span, nil, class: 'go') +
          content_tag(:span, nil, class: 'caution') +
          content_tag(:span, nil, class: 'stop')
      end
    end

    def state_bar(resource, _options = {})
      machine = resource.class.state_machine
      state = resource.state
      state = machine.state(state.to_sym) unless state.is_a?(StateMachine::State) || state.nil?
      render 'state_bar', states: machine.states, current_state: state, resource: resource
    end

    def main_state_bar(resource, options = {})
      content_for(:main_statebar, state_bar(resource, options))
    end

    def main_state_bar_tag
      content_for(:main_statebar) if content_for?(:main_statebar)
    end

    def main_list(*args)
      options = args.extract_options!
      list *args, options.deep_merge(content_for: { settings: :meta_toolbar, pagination: :meta_toolbar, actions: :main_toolbar })
    end

    def janus(*args, &_block)
      options = args.extract_options!
      name = args.shift || ("#{controller_path}-#{action_name}-" + caller.first.split(/\:/).second).parameterize

      lister = Ekylibre::Support::Lister.new(:face)
      yield lister
      faces = lister.faces

      return '' unless faces.any?

      faces_names = faces.map { |f| f.args.first.to_s }

      active_face = nil
      if pref = current_user.preferences.find_by(name: "interface.janus.#{name}.current_face")
        face = pref.value.to_s
        active_face = face if faces_names.include? face
      end
      active_face ||= faces_names.first

      # Adds views
      html = faces.map do |face|
        face_name = face.args.first.to_s
        classes = ['face']
        classes << 'active' if active_face == face_name
        content_tag(:div, id: "face-#{face_name}", data: { face: face_name }, class: classes, &face.block)
      end.join.html_safe

      # Adds toggle buttons
      if faces.count > 1
        content_for :view_toolbar do
          content_tag(:div, data: { janus: url_for(controller: '/backend/januses', action: :toggle, id: name, default: faces_names.first) }, class: 'btn-group') do
            faces.collect do |face|
              face_name = face.args.first.to_s
              classes = ['btn', 'btn-default']
              classes << 'active' if face_name == active_face
              link_to(face_name, data: { toggle: 'face' }, class: classes, title: face_name.tl) do
                content_tag(:i, '', class: "icon icon-#{face_name}") + ' '.html_safe + face_name.tl
              end
            end.join.html_safe
          end
        end
      end

      html
    end

    def resource_info(name, options = {}, &block)
      value = resource.send(name)
      return nil if value.blank? && !options[:force]
      nomenclature = options.delete(:nomenclature)
      if nomenclature.is_a?(TrueClass)
        value = Nomen.find(name.to_s.pluralize, value)
      elsif nomenclature.is_a?(Symbol)
        value = Nomen.find(nomenclature, value)
      end
      label = options.delete(:label) || resource_model.human_attribute_name(name)
      if block_given?
        info(label, capture(value, &block), options)
      else
        info(label, value.respond_to?(:l) ? value.l : value, options)
      end
    end

    def info(label, value, options = {}, &_block)
      css_class = "#{options.delete(:level) || :med}-info"
      options[:class] = if options[:class]
                          options[:class].to_s + ' ' + css_class
                        else
                          css_class
                        end
      options[:class] << ' important' if options.delete(:important)
      content_tag(:div, options) do
        content_tag(:span, label, class: 'title') +
          content_tag(:span, value, class: 'value')
      end
    end

    def infos(options = {}, &block)
      css_class = 'big-infos'
      if options[:class]
        options[:class] += ' ' + css_class
      else
        options[:class] = css_class
      end
      content_tag(:div, options, &block)
    end
  end
end
