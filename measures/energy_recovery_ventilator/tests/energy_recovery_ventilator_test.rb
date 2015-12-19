require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class EnergyRecoveryVentilatorTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  
  def test_do_not_apply
     
    # Create an instance of the measure
    measure = EnergyRecoveryVentilator.new
    
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
    "fan_pressure_increase_inH2O" => 1.0,
    "sensible_eff_at_100_heating" => 0.76,
    "latent_eff_at_100_heating" => 0.68,
    "sensible_eff_at_75_heating" => 0.81,
    "latent_eff_at_75_heating" => 0.73,
    "sensible_eff_at_100_cooling" => 0.76,
    "latent_eff_at_100_cooling" => 0.68,
    "sensible_eff_at_75_cooling" => 0.81,
    "latent_eff_at_75_cooling" => 0.73
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

  def test_apply_to_all_loops
     
    # Create an instance of the measure
    measure = EnergyRecoveryVentilator.new
    
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
    "fan_pressure_increase_inH2O" => 1.0,
    "sensible_eff_at_100_heating" => 0.76,
    "latent_eff_at_100_heating" => 0.68,
    "sensible_eff_at_75_heating" => 0.81,
    "latent_eff_at_75_heating" => 0.73,
    "sensible_eff_at_100_cooling" => 0.76,
    "latent_eff_at_100_cooling" => 0.68,
    "sensible_eff_at_75_cooling" => 0.81,
    "latent_eff_at_75_cooling" => 0.73
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
  
  def test_na_because_already_have_ervs
     
    # Create an instance of the measure
    measure = EnergyRecoveryVentilator.new
    
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
    "fan_pressure_increase_inH2O" => 1.0,
    "sensible_eff_at_100_heating" => 0.76,
    "latent_eff_at_100_heating" => 0.68,
    "sensible_eff_at_75_heating" => 0.81,
    "latent_eff_at_75_heating" => 0.73,
    "sensible_eff_at_100_cooling" => 0.76,
    "latent_eff_at_100_cooling" => 0.68,
    "sensible_eff_at_75_cooling" => 0.81,
    "latent_eff_at_75_cooling" => 0.73
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
  
end
