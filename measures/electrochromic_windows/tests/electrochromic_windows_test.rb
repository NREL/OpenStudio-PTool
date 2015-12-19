######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.  
#  All rights reserved.
#  
#  This library is free software you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ElectrochromicWindowsTests < MiniTest::Unit::TestCase

  def test_primary_school

    # create an instance of the measure
    measure = ElectrochromicWindows.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
   
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PrimarySchool-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized)
    model = model.get
    runner.setLastOpenStudioModel(model)
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
    "run_measure" => 1
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    show_output(result)    
    
    workspace.save("#{Dir.pwd}/output/PrimarySchool-90.1-2010-ASHRAE 169-2006-5A.idf",true)
    
    assert(result.value.valueName == "Success") 

  end 

  def test_large_office_5A

    # create an instance of the measure
    measure = ElectrochromicWindows.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
   
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized)
    model = model.get
    runner.setLastOpenStudioModel(model)
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
    "run_measure" => 1
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    show_output(result)    
    
    workspace.save("#{Dir.pwd}/output/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.idf",true)
    
    assert(result.value.valueName == "Success")

  end

  def test_large_office_2A

    # create an instance of the measure
    measure = ElectrochromicWindows.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
   
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized)
    model = model.get
    runner.setLastOpenStudioModel(model)
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
    "run_measure" => 1
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    show_output(result)    
    
    workspace.save("#{Dir.pwd}/output/LargeOffice-90.1-2010-ASHRAE 169-2006-2A.idf",true)
    
    assert(result.value.valueName == "Success")

  end
    
end
