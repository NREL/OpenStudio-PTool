require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class SupplyAirTemperatureResetBasedOnOutdoorAirTemperature_Test < MiniTest::Unit::TestCase

  def test_building_658
     
    # Create an instance of the measure
    measure = SupplyAirTemperatureResetBasedOnOutdoorAirTemperature.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/658.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "run_measure" => 1
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
    assert(result.value.valueName == "Success")    
    
    # Ensure it added SAT reset based on OAT to the airloops called
    # AirLoop 624
    model.getAirLoopHVACs.each do |air_loop|
      n = air_loop.name.get
      if n == "AirLoop 618"
        assert(air_loop.supplyOutletNode.setpointManagerOutdoorAirReset.is_initialized)
      end
    end
      
  end    
  
  def test_building_659
     
    # Create an instance of the measure
    measure = SupplyAirTemperatureResetBasedOnOutdoorAirTemperature.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/659.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "run_measure" => 1
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
    assert(result.value.valueName == "Success")    
    
    # Ensure it added SAT reset based on OAT to the airloops called
    # AirLoop 624
    model.getAirLoopHVACs.each do |air_loop|
      n = air_loop.name.get
      if n == "AirLoop 619" or n == "AirLoop 622"
        assert(air_loop.supplyOutletNode.setpointManagerOutdoorAirReset.is_initialized)
      end
    end
      
  end 
  
  def test_building_660
     
    # Create an instance of the measure
    measure = SupplyAirTemperatureResetBasedOnOutdoorAirTemperature.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/660.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "run_measure" => 1
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

    # Building has 2 multizone VAV systems, both with SAT reset based on OAT
    # already installed. Measure result should be "NA."
    assert(result.value.valueName == "NA")
      
  end

end
