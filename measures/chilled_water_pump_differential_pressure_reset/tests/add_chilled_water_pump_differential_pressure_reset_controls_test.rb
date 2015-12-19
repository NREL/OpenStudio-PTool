require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ChilledWaterPumpDifferentialPressureResetTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ChilledWaterPumpDifferentialPressureReset.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end

  def test_is_not_applicable_to_test_models
  
	["LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm","SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName)
	end
  end
  
  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
  
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The autosized secondary chilled water variable speed pump object named Chilled Water Loop Secondary Pump has been removed from the chilled water plant loop named Chilled Water Loop."})
	refute_nil(result.info.find {|m| m.logMessage == "A secondary chilled water variable speed pump with a part load performance curve representing best practice static pressure reset control and named Autosized Chilled Water Loop Secondary Pump-> Variable Speed Pump + Static Pressure Reset Control has been added to the chilled water plant loop named Chilled Water Loop. A minimum flow rate of 254.6 gpm, based on 30% of the rated flow rate, was assigned. This object replaces the autosized constant speed pump named Chilled Water Loop Secondary Pump located on the chilled water plant loop named Chilled Water Loop. A sizing run was executed for determining variable speed pump settings for rated flow rate and rated power consumption. Values for pump head, motor efficiency, fraction of motor efficiencies to fluid stream and control type from the autosized variable speed pump object named Chilled Water Loop Secondary Pump object were re-used."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
  
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The model does not contain any constant or variable speed secondary chilled water pump objects for this measure to apply a differential pressure reset control strategy to. The measure is not applicible."})
  end
    
  def applytotestmodel(model_file)
  
	measure = ChilledWaterPumpDifferentialPressureReset.new
	
	# Run each test in its own directory so we don't have to worry about cleaning up sizing run files
	dirname = "run_#{rand(1000)}"
	Dir.mkdir(dirname)
	Dir.chdir(dirname) do
		# create an instance of a runner
		runner = OpenStudio::Ruleset::OSRunner.new
    puts "****************** Running #{model_file} *******************"
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
    
    # show the output
    show_output(result)    
    
		return result, model
	end
  end  
 
end
