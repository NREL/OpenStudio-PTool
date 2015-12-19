require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ExteriorLightingControlsTest < MiniTest::Unit::TestCase
  
  def test_sec_school_1980_2004_3B

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SecondarySchool-DOE Ref 1980-2004-ASHRAE 169-2006-3B.osm")
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

  end  
  
  def test_small_hotel_2010_2A

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallHotel-90.1-2010-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Create an empty argument map (this measure has no arguments)
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

  end
  
  def test_small_hotel_2010_3B

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Create an empty argument map (this measure has no arguments)
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

  end

  def test_small_hotel_2010_4A

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallHotel-90.1-2010-ASHRAE 169-2006-4A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Create an empty argument map (this measure has no arguments)
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

  end

  def test_small_hotel_2010_5A

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallHotel-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Create an empty argument map (this measure has no arguments)
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

  end  

end
