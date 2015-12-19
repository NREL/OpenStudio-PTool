require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class PlugLoadControlsTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  def test_small_office
     
    # Create an instance of the measure
    measure = PlugLoadControls.new
    
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
    "unoc_pct_red" => 0.25,
    "oc_pct_red" => 0.1,
    "apply_weekday" => true,
    "start_weekday" => 18.0,
    "end_weekday" => 9.0,
    "apply_saturday" => true,
    "start_saturday" => 18.0,
    "end_saturday" => 18.0,
    "apply_sunday" => true,
    "start_sunday" => 18.0,
    "end_sunday" => 18.0
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
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/small_office_1980-2004_w_plugload_ctrl.osm"),true)    
    
  end  
  
  def test_secondary_school
     
    # Create an instance of the measure
    measure = PlugLoadControls.new
    
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
    "unoc_pct_red" => 0.25,
    "oc_pct_red" => 0.1,
    "apply_weekday" => true,
    "start_weekday" => 18.0,
    "end_weekday" => 9.0,
    "apply_saturday" => true,
    "start_saturday" => 18.0,
    "end_saturday" => 18.0,
    "apply_sunday" => true,
    "start_sunday" => 18.0,
    "end_sunday" => 18.0
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
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/secondary_school_90.1-2010_w_plugload_ctrl.osm"),true)  
      
  end
  
end
