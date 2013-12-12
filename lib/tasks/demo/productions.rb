# -*- coding: utf-8 -*-
demo :productions do

  Ekylibre::fixturize :activities_import do |w|
    #############################################################################

    # attributes to map family
    families = {
      "CEREA" => :straw_cereal_crops,
      "COPLI" => :oilseed_crops,
      "CUFOU" => :prairie,
      "ANIMX" => :cattle_farming
      # "XXXXX" => :none,
      # "NINCO" => :none
    }
    # attributes to map family by activity name
    families_by_activity_name = {
      "Orge hiver" => :straw_cereal_crops,
      "Blé tendre" => :straw_cereal_crops,
      "Blé dur" => :straw_cereal_crops,
      "Maïs sec" => :maize_crops,
      "Triticale" => :straw_cereal_crops,
      "Jachère annuelle" => :fallow_land,
      "Tournesol" => :oilseed_crops,
      "Sorgho" => :prairie,
      "Prairie temporaire et artificielle" => :prairie,
      "Bovins lait" => :cattle_farming,
      "Veau 8-15 J" => :cattle_farming,
      "Taurillons lait" => :cattle_farming,
      "ADMINISTRATIF" => :exploitation,
      "BATIMENT" => :exploitation,
      "COMMERCIALISATION" => :sales,
      "MECANISATION" => :exploitation,
      "PERSONNEL" => :exploitation
    }
    # attributes to map nature
    natures = {
      "PRINC" => :main,
      "AUX" => :auxiliary,
      "" => :none
    }
    # Load file
    file = Rails.root.join("test", "fixtures", "files", "activities_ref_demo.csv")
    CSV.foreach(file, :encoding => "UTF-8", :col_sep => ",", :headers => true, :quote_char => "'") do |row|
      r = OpenStruct.new(:description => row[0],
                         :name => row[1].downcase.capitalize,
                         :family => families_by_activity_name[row[1]],
                         :variant_reference_name => row[3].blank? ? nil :row[3].to_sym,
                         :nature => (natures[row[4]] || :none).to_s,
                         :campaign_harvest_year => row[5].blank? ? nil : row[5].to_i,
                         :work_number_storage => row[6].blank? ? nil : row[6].to_s
                         )
      product_support = Product.find_by(work_number: r.work_number_storage)

      # Create a campaign if not exist
      if r.campaign_harvest_year.present?
        campaign = Campaign.find_by(harvest_year: r.campaign_harvest_year)
        campaign ||= Campaign.create!(harvest_year: r.campaign_harvest_year, closed: false)
      end
      # Create an activity if not exist
      activity   = Activity.find_by(description: r.description)
      activity ||= Activity.create!(:nature => r.nature, :family => r.family, :name => r.name, :description => r.description)
      if r.variant_reference_name
        product_nature_variant_sup = ProductNatureVariant.find_by(reference_name: r.variant_reference_name)
        product_nature_variant_sup ||= ProductNatureVariant.import_from_nomenclature(r.variant_reference_name)
        if product_nature_variant_sup and product_support.present?
          # find a production corresponding to campaign , activity and product_nature
          pro = Production.where(:campaign_id => campaign.id, :activity_id => activity.id, :variant_id => product_nature_variant_sup.id).first
          # or create it
          pro ||= activity.productions.create!(:variant_id => product_nature_variant_sup.id, :campaign_id => campaign.id, :static_support => true)
          # create a support for this production
          pro.supports.create!(:storage_id => product_support.id)
          if product_support.is_a?(CultivableLandParcel)
            # create a name for the plant correponding to product_nature_nomen in XML Nomenclature
            plant_name = (Nomen::ProductNatureVariants.find(r.variant_reference_name).human_name + " " + campaign.name + " " + product_support.work_number)
            # create a work number for the plant
            plant_work_nb = (r.variant_reference_name.to_s + "-" + campaign.name + "-" + product_support.work_number)
            # create the plant
            plant = Plant.create!(:variant_id => product_nature_variant_sup.id, :work_number => plant_work_nb , :name => plant_name, :born_at => Time.now, :initial_owner => Entity.of_company, :default_storage => product_support)
            # localize the plant in the cultivable_land_parcel
            ProductLocalization.create!(:container_id => product_support.id, :product_id => plant.id, :nature => :interior, :started_at => Time.now, :arrival_cause => :birth)
          end
        elsif product_nature_variant_sup
          pro = Production.where(:variant_id => product_nature_variant_sup.id, :campaign_id => campaign.id, :activity_id => activity.id).first
          pro ||= activity.productions.create!(:variant_id => product_nature_variant_sup.id, :campaign_id => campaign.id)
        end
      end
      w.check_point
    end
  end

end