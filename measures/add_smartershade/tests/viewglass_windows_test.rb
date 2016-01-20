require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ViewglassWindowsTests < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ViewglassWindows.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end
    
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop 'VAV WITH REHEAT' with OA controller named 'VAV WITH REHEAT OA Controller' has had a minimum OA rate set to 4,637.36 from 46,373.57."})
  end
    
  def applytotestmodel(model_file, weather_file = "USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw")
  
	measure = ViewglassWindows.new

	# Run each test in its own directory so we don't have to worry about cleaning up sizing run files
	dirname = "run_#{rand(1000)}"
	Dir.mkdir(dirname)
	Dir.chdir(dirname) do
		# create an instance of a runner
		runner = OpenStudio::Ruleset::OSRunner.new

		# load the test model
		translator = OpenStudio::OSVersion::VersionTranslator.new
		path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
		model = translator.loadModel(path)
		assert((not model.empty?))
		model = model.get

		# Set weather file
		wf_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{weather_file}")
		wf = OpenStudio::EpwFile.new(wf_path)
		OpenStudio::Model::WeatherFile.setWeatherFile(model, wf)
		
		# get arguments
		arguments = measure.arguments(model)
		argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

		# run the measure
		measure.run(model, runner, argument_map)
		result = runner.result
		show_output(result)
    return result, model
    
    
	end
  end  
 
end
