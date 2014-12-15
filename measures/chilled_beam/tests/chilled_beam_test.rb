require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class AddChilledBeamTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  
  def test_do_not_apply
     
    # Create an instance of the measure
    measure = AddChilledBeam.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/small_office_1980-2004.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
      "apply_measure" => "FALSE",
      "cooled_beam_type" => "Active",
      "existing_plant_loop_name" => "Create New",
      "new_loop_pump_head" => 4.0,
      "air_loop_name" => "Create New",
      "new_airloop_fan_pressure_rise" => 12,
      "supply_air_vol_flow_rate" => 4,
      "max_tot_chw_vol_flow_rate" => 4,
      "number_of_beams" => 2,
      "beam_length" => 5,
      "design_inlet_water_temperature" => 60,
      "design_outlet_water_temperature" => 65,
      "coil_surface_area_per_coil_length" => 1.6,
      "coefficient_alpha" => 1,
      "coefficient_n1" => 1.354,
      "coefficient_n2" => 1,
      "coefficient_n3" => 1,
      "coefficient_a0" => 1,
      "coefficient_k1" => 1,
      "coefficient_n" => 1,
      "coefficient_kin" => 1,
      "leaving_pipe_inside_dia" => "1/2 Type K"
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "NA")    
      
  end

  def test_apply_to_office
  
    # Create an instance of the measure
    measure = AddChilledBeam.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/small_office_1980-2004.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
      "apply_measure" => "TRUE",
      "cooled_beam_type" => "Active",
      "existing_plant_loop_name" => "Create New",
      "new_loop_pump_head" => 4.0,
      "air_loop_name" => "Create New",
      "new_airloop_fan_pressure_rise" => 12.0,
      "supply_air_vol_flow_rate" => 4,
      "max_tot_chw_vol_flow_rate" => 4,
      "number_of_beams" => 2,
      "beam_length" => 5,
      "design_inlet_water_temperature" => 60,
      "design_outlet_water_temperature" => 65,
      "coil_surface_area_per_coil_length" => 1.6,
      "coefficient_alpha" => 1,
      "coefficient_n1" => 1.354,
      "coefficient_n2" => 1,
      "coefficient_n3" => 1,
      "coefficient_a0" => 1,
      "coefficient_k1" => 1,
      "coefficient_n" => 1,
      "coefficient_kin" => 1,
      "leaving_pipe_inside_dia" => "1/2 Type K"
    }
    
    i = 0
    arg_values.each do |name, val|
      puts "#{name} = #{val}"
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")    
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/small_office_1980-2004_with_chilled_beams.osm"),true)    
    
  end  

  def test_apply_to_school
  
    # Create an instance of the measure
    measure = AddChilledBeam.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/secondary_school_90.1-2010.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
      "apply_measure" => "TRUE",
      "cooled_beam_type" => "Active",
      "existing_plant_loop_name" => "Create New",
      "new_loop_pump_head" => 4.0,
      "air_loop_name" => "Create New",
      "new_airloop_fan_pressure_rise" => 12.0,
      "supply_air_vol_flow_rate" => 4,
      "max_tot_chw_vol_flow_rate" => 4,
      "number_of_beams" => 2,
      "beam_length" => 5,
      "design_inlet_water_temperature" => 60,
      "design_outlet_water_temperature" => 65,
      "coil_surface_area_per_coil_length" => 1.6,
      "coefficient_alpha" => 1,
      "coefficient_n1" => 1.354,
      "coefficient_n2" => 1,
      "coefficient_n3" => 1,
      "coefficient_a0" => 1,
      "coefficient_k1" => 1,
      "coefficient_n" => 1,
      "coefficient_kin" => 1,
      "leaving_pipe_inside_dia" => "1/2 Type K"
    }
    
    i = 0
    arg_values.each do |name, val|
      puts "#{name} = #{val}"
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")    
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/secondary_school_90.1-2010_with_chilled_beams.osm"),true)    
    
  end  
   
  
end
