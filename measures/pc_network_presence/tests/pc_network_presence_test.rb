require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class PCNetworkPresenceTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  
  def test_do_not_apply
     
    # Create an instance of the measure
    measure = PCNetworkPresence.new
    
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
    "fraction_value" => 0.1,
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
    assert(result.value.valueName == "NA")    
      
  end

  def test_apply_to_all_days
     
    # Create an instance of the measure
    measure = PCNetworkPresence.new
    
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
    "fraction_value" => 0.1,
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
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/small_office_1980-2004_with_adv_pwr_strips.osm"),true)    
    
  end  
  
  def test_apply_to_weekdays_only
     
    # Create an instance of the measure
    measure = PCNetworkPresence.new
    
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
    "fraction_value" => 0.1,
    "apply_weekday" => true,
    "start_weekday" => 18.0,
    "end_weekday" => 9.0,
    "apply_saturday" => false,
    "start_saturday" => 18.0,
    "end_saturday" => 18.0,
    "apply_sunday" => false,
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
      
    model.save(OpenStudio::Path.new("#{Dir.pwd}/secondary_school_90.1-2010_with_pc_network_presence.osm"),true)  
      
  end
  
end
