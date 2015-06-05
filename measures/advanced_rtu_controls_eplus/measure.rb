#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class AdvancedRTUControlsEplus < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AdvancedRTUControlsEplus"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
     
    ems_path = '../AdvancedRTUControls/ems_advanced_rtu_controls.ems'
    if File.exist? ems_path
      ems_string = File.read(ems_path)     
    else
      ems_path2 = Dir.glob('../../*/ems_advanced_rtu_controls.ems')
      ems_path1 = ems_path2[0]
      if File.exist? ems_path1
        ems_string = File.read(ems_path1)
      else
        runner.registerError("ems_advanced_rtu_controls.ems file not located")    
      end
    end
    
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{emsProgram.size} EMS objects.")

    #reporting final condition of model
    #runner.registerFinalCondition("The building finished with #{emsProgram.size} EMS objects.")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AdvancedRTUControlsEplus.new.registerWithApplication