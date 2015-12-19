require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class AdvancedWindowsTest < MiniTest::Unit::TestCase

  def test_do_not_apply
     
    # Create an instance of the measure
    measure = AdvancedWindows.new
    
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
    "run_measure" => 0,
    "window_r_value_ip" => 10.0,
    "window_shgc" => 0.75,
    "window_vlt" => 0.75
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val),"Could not set '#{name}' to '#{val}'.")
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished as expected
    assert(result.value.valueName == "NA")    
      
  end

  def test_small_office
     
    # Create an instance of the measure
    measure = AdvancedWindows.new
    
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
    "run_measure" => 1,
    "window_r_value_ip" => 10.0,
    "window_shgc" => 0.75,
    "window_vlt" => 0.75
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val),"Could not set '#{name}' to '#{val}'.")
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished as expected
    assert(result.value.valueName == "Success")
      
    model.save("output/office_after_measure.osm", true)  
      
  end

  def test_secondary_school
     
    # Create an instance of the measure
    measure = AdvancedWindows.new
    
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
    "run_measure" => 1,
    "window_r_value_ip" => 10.0,
    "window_shgc" => 0.75,
    "window_vlt" => 0.75
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val),"Could not set '#{name}' to '#{val}'.")
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished as expected
    assert(result.value.valueName == "Success")
     
    model.save("output/school_after_measure.osm", true)
      
  end

end
