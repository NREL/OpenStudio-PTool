
require 'csv'

# Method to search through a hash for an object that meets the
# desired search criteria, as passed via a hash.
#
# @param hash_of_objects [Hash] hash of objects to search through
# @param search_criteria [Hash] hash of search criteria
# @return [Hash] Return tbe first matching object hash if successful, nil if not.
# @example Find the motor that meets these size criteria
#   search_criteria = {
#   'template' => template,
#   'number_of_poles' => 4.0,
#   'type' => 'Enclosed',
#   }
#   motor_properties = self.model.find_object(motors, search_criteria)
def find_object(hash_of_objects, search_criteria)
  
  desired_object = nil
  matching_objects = []
  
  # Compare each of the objects against the search criteria
  hash_of_objects.each do |object|
    #puts "***********************"
    meets_all_search_criteria = true
    search_criteria.sort.each do |key, value|
      # Don't check non-existent search criteria
      next unless object.has_key?(key)
      # Stop as soon as one of the search criteria is not met 
      if object[key] != value 
        #puts "#{object[key]} != #{value}"
        meets_all_search_criteria = false
        break
      else
        #puts "#{object[key]} = #{value}"
      end
    end
    # Skip objects that don't meet all search criteria
    next if !meets_all_search_criteria
    # If made it here, object matches all search criteria
    matching_objects << object
  end
 
  # Check the number of matching objects found
  if matching_objects.size == 0
    desired_object = nil
    puts "Find object search criteria returned no results. Search criteria:"
    search_criteria.sort.each do |k, v|
      puts "   #{k} => #{v}"
    end 
  elsif matching_objects.size == 1
    desired_object = matching_objects[0]
  else 
    desired_object = matching_objects[0]
    puts "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. \n Search criteria: \n #{search_criteria} \n  All results: \n #{matching_objects.join("\n")}"
  end
 
  return desired_object
 
end

# Loop through all rows
# and export each as a hash
# with keys from the header
def csv_to_json(rows)

  objs = []
  
  headers = rows[0]
  
  for i in 1..rows.size - 1
    row = rows[i]
    obj = {}
    for j in 0..headers.size - 1
      header = headers[j].to_s
      val = row[j]
      obj[header] = val
    end
    objs << obj 
  end

  return objs

end

# Load the metadata csv
metadata_csv = "#{Dir.pwd}/ptool_full_analysis_metadata.csv"
metadata_rows = CSV.read(metadata_csv)
metadata_cols = metadata_rows.transpose
metadata_headers = metadata_rows[0]
metadata = csv_to_json(metadata_rows)
puts "found #{metadata.size} rows in metadata"

# Get the list of varialbes and outputs
variables = []
outputs = []
metadata.each do |data|
  type = data['type_of_variable']
  if type == 'variable'
    variables << data['name']
  elsif type == 'output'
    next if data['name'].include?('applicable')
    outputs << data['name']
  end
end
outputs = outputs.sort
variables = variables.sort

puts "variables = #{variables.size}: #{variables.join(', ')}"
puts "outputs = #{outputs.size}: #{outputs.join(', ')}"

# Load the results csv
results_csv = "#{Dir.pwd}/ptool_full_analysis.csv"
results_rows = CSV.read(results_csv)
results_cols = results_rows.transpose
results_headers = results_rows[0]
runs = csv_to_json(results_rows)
puts "found #{runs.size} runs in results"

# Get the list of building types, climate zones, and templates
building_types = []
climate_zones = []
templates = []
results_cols.each do |col|
  if col[0] == 'create_doe_prototype_building.building_type'
    building_types = col.drop(1).uniq
  elsif col[0] == 'create_doe_prototype_building.climate_zone'
    climate_zones = col.drop(1).uniq
  elsif col[0] == 'create_doe_prototype_building.template'
    templates = col.drop(1).uniq
  end
end
building_types = building_types.sort
climate_zones = climate_zones.sort
templates = templates.sort

puts "building_types = #{building_types.size}: #{building_types.join(', ')}"
puts "climate_zones = #{climate_zones.size}: #{climate_zones.join(', ')}"
puts "templates = #{templates.size}: #{templates.join(', ')}"
  
# For each variable (measure), calculate the
# savings for every building type/climate zone/template combo
variables.sort.each do |var_of_interest|
  next unless var_of_interest == 'exterior_lighting_control.run_measure'
  # Get the name of the N/A inidicator
  na_indicator = ""
  if match_data = /(.*)\.run_measure/.match(var_of_interest)
    na_indicator = "#{match_data[1]}.applicable"
  else
    puts "ERROR - Could not determine measure name from variable #{var_of_interest}" 
    next
  end

  num_runs_applicable = 0
  
  all_pct_savings = Hash.new {|h,k| h[k] = [] }  


  # Add the header
  CSV.open("#{Dir.pwd}/#{var_of_interest}.csv", 'w') do |csv|
    csv << ['building_type', 'climate_zone', 'template'] + outputs
    #csv << outputs
  end
  
  building_types.each do |building_type|
  climate_zones.each do |climate_zone|
  templates.each do |template|

    puts "#{building_type} #{climate_zone} #{template}"
  
    # Get the baseline run, where all variables are 0
    baseline_search_criteria = {
    'create_doe_prototype_building.building_type' => building_type,
    'create_doe_prototype_building.climate_zone' => climate_zone,
    'create_doe_prototype_building.template' => template,
    }
    variables.each do |var|
      baseline_search_criteria[var] = '0.0' # Not applied
    end
    baseline = find_object(runs, baseline_search_criteria)
    puts "baseline = #{baseline}"
   
    # Get the applied run, where all variables are 0
    # except for the variable of interest
    applied_search_criteria = {
    'create_doe_prototype_building.building_type' => building_type,
    'create_doe_prototype_building.climate_zone' => climate_zone,
    'create_doe_prototype_building.template' => template,
    }
    variables.each do |var|
      if var == var_of_interest
        applied_search_criteria[var] = '1.0' # Applied
      else
        applied_search_criteria[var] = '0.0' # Not applied
      end
    end
    applied = find_object(runs, applied_search_criteria)
    puts "applied = #{applied}"
    
    if baseline.nil? || applied.nil?
      puts "ERROR - Could not find one of either baseline or applied runs"
      exit
    end
  
    # Don't record results if the measure was applied
    # but returned "Not Applicable"
    if applied[na_indicator] == 'false'
      #puts "Not Applicable to this run"
      next
    end
    
    num_runs_applicable += 1
  
    # Calculate the savngs for each output
    row = ["#{building_type}", "#{climate_zone}", "#{template}"]
    outputs.each do |output|
      baseline_val = baseline[output]
      applied_val = applied[output]
      pct_svgs = nil
      if baseline_val == '0.0' || applied_val == '0.0'
        pct_svgs = 0.0
      else
        pct_svgs = ((baseline_val.to_f - applied_val.to_f) / baseline_val.to_f ) * 100
      end
      all_pct_savings[output] << pct_svgs
      row << pct_svgs.round(1)
      next if pct_svgs == 0
      puts "   #{pct_svgs.round(1)}%  #{output}"
    end
  
    CSV.open("#{Dir.pwd}/#{var_of_interest}.csv", 'a') do |csv|
      csv << row
    end  
  
  end
  end
  end
  
  puts "*** #{var_of_interest} Overall Impacts ***"
  puts "Applied to #{num_runs_applicable} of #{runs.size/variables.size - 1} Runs"
  all_pct_savings.each do |output, vals|
    avg = vals.inject{ |sum, el| sum + el }.to_f / vals.size
    puts "#{avg.round(1)}% #{output} Avg. Impact."
  end

end
