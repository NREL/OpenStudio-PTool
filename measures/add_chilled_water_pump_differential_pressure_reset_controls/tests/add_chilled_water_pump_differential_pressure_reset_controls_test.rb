require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddChilledWaterPumpDifferentialPressureResetControlsTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments
    # create an instance of the measure
    measure = AddChilledWaterPumpDifferentialPressureResetControls.new

	# load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/chw_pump_diff_test_model_1.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
	
	# get arguments and test that they are what we are expecting - zero arguments
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
	
	# Run the measure
	measure.run(model, runner, argument_map)  
	result = runner.result
	show_output(result)
	
  
  end

end # end of class
