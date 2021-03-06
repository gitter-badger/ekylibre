module Clean
  module Locales
    class << self
      ENUMERIZES = Dir.glob(Rails.root.join('app', 'models', '*.rb')).sort.inject({}) do |hash, file|
        enumerizes = {}
        File.open(file, 'rb:UTF-8').each_line do |line|
          next unless line =~ /\A\s*enumerize/
          line = line.strip.split(/[\(\,\s\)]+/)
          name = line[1][1..-1].to_sym
          source = line[3].to_s
          next unless source.start_with?('Nomen::')
          elements = source.gsub('Nomen::', '').split('.')
          enumerizes[name] = [:nomen, elements.shift.underscore.to_sym]
          method_name = elements.shift
          if method_name =~ /\Aall(\W|\z)/
            enumerizes[name] << :items
          else
            enumerizes[name] << :choices
            enumerizes[name] << method_name.to_sym
          end
        end
        hash[file.split(/\W/)[-2].to_sym] = enumerizes unless enumerizes.empty?
        hash
      end.freeze

      def compile_complement(locale)
        locale_dir = Rails.root.join('config', 'locales', locale.to_s)
        hash = {}
        hash.deep_merge!(Clean::Support.yaml_to_hash(locale_dir.join('models.yml')))
        hash.deep_merge!(Clean::Support.yaml_to_hash(locale_dir.join('aggregators.yml')))
        hash.deep_merge!(Clean::Support.yaml_to_hash(locale_dir.join('procedures.yml')))
        hash.deep_merge!(Clean::Support.yaml_to_hash(locale_dir.join('nomenclatures.yml')))

        complement = { enumerize: {} }
        enumerize = complement[:enumerize]
        for model, enumerizes in ENUMERIZES
          enumerize[model] = {}
          for name, source in enumerizes
            if source.first == :nomen
              if n = hash[locale][:nomenclatures][source[1]]
                if (n = n[source[2]]) && n.is_a?(Hash)
                  n = n[source[3]] if source[2] == :choices
                  enumerize[model][name] = n
                end
              end
            else
              Rails.logger.error "#{source.first.inspect} nor supported"
            end
          end
        end

        # enumerize[:product_reading] ||= {}
        # enumerize[:product_reading][:indicator_name] = Clean::Support.rec(hash, locale, :nomenclatures, :indicators, :items)
        # enumerize[:product_nature_variant_reading] ||= {}
        # enumerize[:product_nature_variant_reading][:indicator_name] = Clean::Support.rec(hash, locale, :nomenclatures, :indicators, :items)
        enumerize[:intervention] ||= {}
        enumerize[:intervention][:procedure_name] = Clean::Support.rec(hash, locale, :procedures)
        enumerize[:intervention_parameter] ||= {}
        enumerize[:intervention_parameter][:reference_name] = Clean::Support.rec(hash, locale, :procedure_parameters)
        enumerize[:listing] ||= {}
        enumerize[:listing][:root_model] = Clean::Support.rec(hash, locale, :activerecord, :models)

        File.open(locale_dir.join('complement.yml'), 'wb') do |f|
          f.write "# This file is totally generated from other translations for convenience.\n"
          f.write "# Do not touch this please, it's quite useless.\n"
          f.write Clean::Support.hash_to_yaml(locale => complement)
        end
      end
    end
  end
end
