require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class ReplaceDesktopsWithLaptopsTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  def test_fail_because_initial_model_didnt_have_elec_equip
     
    # Create an instance of the measure
    measure = ReplaceDesktopsWithLaptops.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure failed as expected
    assert(result.value.valueName == "Fail")    
      
  end  
  
  def test_medium_office
     
    # Create an instance of the measure
    measure = ReplaceDesktopsWithLaptops.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/MediumOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")
      
  end
  
end
