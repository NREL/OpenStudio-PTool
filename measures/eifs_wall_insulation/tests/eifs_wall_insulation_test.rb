require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class EIFSWallInsulationTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end
  
  def test_do_not_apply
     
    # Create an instance of the measure
    measure = EIFSWallInsulation.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Different Wall Constructions.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    run_measure = arguments[0].clone
    assert(run_measure.setValue(0))
    argument_map["run_measure"] = run_measure    
    
    r_value_ip = arguments[1].clone
    assert(r_value_ip.setValue(30.0))
    argument_map["r_value_ip"] = r_value_ip     
    
    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "NA")    
      
  end    

  def test_different_wall_constructions
     
    # Create an instance of the measure
    measure = EIFSWallInsulation.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Different Wall Constructions.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    run_measure = arguments[0].clone
    assert(run_measure.setValue(1))
    argument_map["run_measure"] = run_measure    
    
    r_value_ip = arguments[1].clone
    assert(r_value_ip.setValue(30.0))
    argument_map["r_value_ip"] = r_value_ip     
    
    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")    
      
    # Wall surfaces called Surface 20, Surface 2, Surface 14 should have insulation applied
    applied_names = ["Surface 20", "Surface 2", "Surface 14"]
    applied_names.each do |name|
      wall = model.getSurfaceByName(name).get
      construction = wall.construction.get.to_Construction.get
      outside_layer = construction.layers[0]
      assert(outside_layer.name.get.include?("Expanded Polystyrene") == true)
    end

    # Roof surfaces called Surface 30, Surface 12 should not have insulation applied    
    not_applied_names = ["Surface 30", "Surface 12"]
    not_applied_names.each do |name|
      wall = model.getSurfaceByName(name).get
      construction = wall.construction.get.to_Construction.get
      outside_layer = construction.layers[0]
      assert(outside_layer.name.get.include?("Expanded Polystyrene") == false)
    end    
    
      
  end  
  
end
