require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class HotWaterPumpDifferentialPressureResetTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = HotWaterPumpDifferentialPressureReset.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end
  
  def test_is_not_applicable_to_test_models
  
	["MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm", "LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName)
	end
  end
  
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary hot water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def applytotestmodel(model_file)
  
	measure = HotWaterPumpDifferentialPressureReset.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

	# Run each test in its own directory so we don't have to worry about cleaning up sizing run files
	dirname = "run_#{rand(1000)}"
	Dir.mkdir(dirname)
	Dir.chdir(dirname) do
		# load the test model
		translator = OpenStudio::OSVersion::VersionTranslator.new
		path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
		model = translator.loadModel(path)
		assert((not model.empty?))
		model = model.get

		# Set weather file
		wf_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw")
		wf = OpenStudio::EpwFile.new(wf_path)
		OpenStudio::Model::WeatherFile.setWeatherFile(model, wf)
		

		# get arguments
		arguments = measure.arguments(model)
		argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

		# run the measure
		measure.run(model, runner, argument_map)
		result = runner.result
		return result, model
    
    # show the output
    show_output(result)    
    
	end
  end  
 
end
