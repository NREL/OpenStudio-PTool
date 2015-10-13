require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class HotWaterSupplyTempResetTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = HotWaterSupplyTempReset.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
  
  def test_is_not_applicable_to_test_models
  
	["MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName)
	end
  end
  
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "An outdoor air reset setpoint manager object named Hot water loop setpoint manager_replaced has replaced the existing scheduled setpoint manager object serving the hot water plant loop named Hot Water Loop. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "An outdoor air reset setpoint manager object named Hot water loop setpoint manager_replaced has replaced the existing scheduled setpoint manager object serving the hot water plant loop named Hot Water Loop. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "No Heating PlantLoop objects found. EEM is not applicable."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "An outdoor air reset setpoint manager object named Hot water loop setpoint manager_replaced has replaced the existing scheduled setpoint manager object serving the hot water plant loop named Hot Water Loop. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "An outdoor air reset setpoint manager object named Hot water loop setpoint manager_replaced has replaced the existing scheduled setpoint manager object serving the hot water plant loop named Hot Water Loop. The setpoint manager resets the hot water setpoint from 71.1 deg C to 82.2 deg C between outdoor air temps of 15.56 Deg C and -6.67 Deg C."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "No Heating PlantLoop objects found. EEM is not applicable."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "No Heating PlantLoop objects found. EEM is not applicable."})
  end
    
  def applytotestmodel(model_file)
  
	measure = HotWaterSupplyTempReset.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/../../../testing_models/#{model_file}")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
	return result, model
  end  
 
end
