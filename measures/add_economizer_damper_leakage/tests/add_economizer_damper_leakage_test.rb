require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddEconomizerDamperLeakageTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = AddEconomizerDamperLeakage.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  # This measure is applicable to all 7 standard models
  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
  
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The availability schedule named Always On Discrete for the Zone HVAC Four Pipe Fan Coil Unit Object named Room_1_Flr_3 ZNFCU has been replaced with a new schedule named Room_1_Flr_3 ZN Occ Sch representing the occupancy profile of the thermal zone named Room_1_Flr_3 ZN."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Variable Speed Pump object named Hot Water Loop Pump on the plant loop named Hot Water Loop Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
	refute_nil(result.info.find {|m| m.logMessage == "Demand side Variable Speed Pump named Chilled Water Loop Secondary Pump on the plant loop named Chilled Water Loop Secondary Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Thermal Zone named GroundFloor_Plenum ZN has no Zone HVAC Equipment objects attached - therefore no schedule objects have been altered."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Variable Speed Pump object named Chilled Water Loop Pump on the plant loop named Chilled Water Loop Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Thermal Zone named FirstFloor_Plenum ZN has no Zone HVAC Equipment objects attached - therefore no schedule objects have been altered."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Constant Speed Pump object named Service Water Loop Pump on the plant loop named Service Water Loop Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The availability schedule named SchoolPrimary Hours_of_operation for the Fan Zone Exhaust Object named Bath_ZN_1_FLR_1 ZN Exhaust Fan has been replaced with a new schedule named Bath_ZN_1_FLR_1 ZN Occ Sch representing the occupancy profile of the thermal zone named Bath_ZN_1_FLR_1 ZN."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Variable Speed Pump object named Hot Water Loop Pump on the plant loop named Hot Water Loop Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The availability schedule named SchoolSecondary Hours_of_operation for the Fan Zone Exhaust Object named Bathrooms_ZN_1_FLR_1 ZN Exhaust Fan has been replaced with a new schedule named Bathrooms_ZN_1_FLR_1 ZN Occ Sch representing the occupancy profile of the thermal zone named Bathrooms_ZN_1_FLR_1 ZN."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Constant Speed Pump object named Chilled Water Loop Primary Pump on the plant loop named Chilled Water Loop Primary Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
	refute_nil(result.info.find {|m| m.logMessage == "Demand side Variable Speed Pump named Chilled Water Loop Secondary Pump on the plant loop named Chilled Water Loop Secondary Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The availability schedule named Always On Discrete for the Zone HVAC Packaged Terminal Air Conditioner Object named CorridorFlr1 ZN PTAC has been replaced with a new schedule named CorridorFlr1 ZN Occ Sch representing the occupancy profile of the thermal zone named CorridorFlr1 ZN."})
	refute_nil(result.info.find {|m| m.logMessage == "Thermal Zone named ElevatorCoreFlr1 ZN has no Zone HVAC Equipment objects attached - therefore no schedule objects have been altered."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Constant Speed Pump object named Service Water Loop Pump 1 on the plant loop named Service Water Loop Pump 1 had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The availability schedule named Always On Discrete 1 for the Zone HVAC Packaged Terminal Heat Pump Object named PTHP has been replaced with a new schedule named Core_ZN ZN Occ Sch representing the occupancy profile of the thermal zone named Core_ZN ZN."})
	refute_nil(result.info.find {|m| m.logMessage == "Thermal Zone named Attic ZN has no Zone HVAC Equipment objects attached - therefore no schedule objects have been altered."})
	refute_nil(result.info.find {|m| m.logMessage == "Supply side Constant Speed Pump object named Service Water Loop Pump on the plant loop named Service Water Loop Pump had a pump control type attribute already set to intermittent. No changes will be made to this object."})
  end
    
  def applytotestmodel(model_file)
  
	measure = AddEconomizerDamperLeakage.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
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
