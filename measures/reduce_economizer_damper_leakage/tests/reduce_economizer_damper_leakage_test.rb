require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class WidenThermostatSetpointTests < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ReduceEconomizerDamperLeakage.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName, m)
	end
  end
    
  def test_is_not_applicable_to_test_models
  
	["PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName, m)
	end
  end
    
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop 'VAV WITH REHEAT' with OA controller named 'VAV WITH REHEAT OA Controller' has had a minimum OA rate set to 4,637.36 from 46,373.57."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop 'VAV_bot WITH REHEAT' with OA controller named 'VAV_bot WITH REHEAT OA Controller' has had a minimum OA rate set to 3,242.98 from 32,429.80."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop '5 Zone PVAV 1' with OA controller named 'Controller Outdoor Air 2' has had a minimum OA rate set to 1,575.72 from 15,757.21."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model contains no OA controllers which are currently configured for operable economizer controls. This measure is not applicable."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop 'VAV_POD_3' with OA controller named 'VAV_POD_3 OA Controller' has had a minimum OA rate set to 1,853.10 from 18,531.01."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop 'FrontLoungeFlr1 ZN SAC' with OA controller named 'FrontLoungeFlr1 ZN SAC OA Sys Controller' has had a minimum OA rate set to 169.32 from 1,693.15."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model contains no OA controllers which are currently configured for operable economizer controls. This measure is not applicable."})
  end
    
  def applytotestmodel(model_file)
  
	measure = ReduceEconomizerDamperLeakage.new

	# Run each test in its own directory so we don't have to worry about cleaning up sizing run files
	dirname = "run_#{rand(1000)}"
	Dir.mkdir(dirname)
	Dir.chdir(dirname) do
		# create an instance of a runner
		runner = OpenStudio::Ruleset::OSRunner.new

		# load the test model
		translator = OpenStudio::OSVersion::VersionTranslator.new
		path = OpenStudio::Path.new(File.dirname(__FILE__) + "/../../../../testing_models/#{model_file}")
		model = translator.loadModel(path)
		assert((not model.empty?))
		model = model.get

		# Set weather file
		wf_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/../../../../weather/USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw")
		wf = OpenStudio::EpwFile.new(wf_path)
		OpenStudio::Model::WeatherFile.setWeatherFile(model, wf)
		
		# get arguments
		arguments = measure.arguments(model)
		argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

		# run the measure
		measure.run(model, runner, argument_map)
		result = runner.result
		return result, model
	end
  end  
 
end
