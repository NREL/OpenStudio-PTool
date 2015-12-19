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
    measure = WidenThermostatSetpoint.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end

  # This measure is applicable to all models
  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
    
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'HotelLarge CLGSETP_SCH' has been changed to HotelLarge CLGSETP_SCH+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'HotelLarge HTGSETP_SCH' has been changed to HotelLarge HTGSETP_SCH-1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'OfficeLarge CLGSETP_DC_SCH' has been changed to OfficeLarge CLGSETP_DC_SCH+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'OfficeLarge HTGSETP_DC_SCH' has been changed to OfficeLarge HTGSETP_DC_SCH-1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'OfficeMedium CLGSETP_SCH_NO_OPTIMUM' has been changed to OfficeMedium CLGSETP_SCH_NO_OPTIMUM+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'OfficeMedium HTGSETP_SCH_NO_OPTIMUM' has been changed to OfficeMedium HTGSETP_SCH_NO_OPTIMUM-1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'SchoolPrimary CLGSETP_SCH_NO_OPTIMUM' has been changed to SchoolPrimary CLGSETP_SCH_NO_OPTIMUM+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'SchoolPrimary HTGSETP_SCH_NO_OPTIMUM' has been changed to SchoolPrimary HTGSETP_SCH_NO_OPTIMUM-1.5F. Inspect the new schedule values using the OS App."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'SchoolSecondary CLGSETP_SCH_NO_SETBACK' has been changed to SchoolSecondary CLGSETP_SCH_NO_SETBACK+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'SchoolSecondary HTGSETP_SCH_YES_OPTIMUM' has been changed to SchoolSecondary HTGSETP_SCH_YES_OPTIMUM-1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'HotelSmall Adva_OccGuestRoom_ClgSP_Sch' has been changed to HotelSmall Adva_OccGuestRoom_ClgSP_Sch+1.5F. Inspect the new schedule values using the OS App."})
	refute_nil(result.info.find {|m| m.logMessage == "The existing heating thermostat 'HotelSmall Adva_OccGuestRoom_HtgSP_Sch' has been changed to HotelSmall Adva_OccGuestRoom_HtgSP_Sch-1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The dual setpoint thermostat object named 90.1-2010 - Office - Attic Thermostat serving thermal zone Attic ZN did not have a cooling setpoint temperature schedule associated with it. The measure will not alter this thermostat object"})
	refute_nil(result.info.find {|m| m.logMessage == "The existing cooling thermostat 'OfficeSmall CLGSETP_SCH_NO_OPTIMUM' has been changed to OfficeSmall CLGSETP_SCH_NO_OPTIMUM+1.5F. Inspect the new schedule values using the OS App."})
  end
    
  def applytotestmodel(model_file)
  
	measure = WidenThermostatSetpoint.new

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
    
    # show the output
    show_output(result)    
    
	return result, model
  end  
 
end
