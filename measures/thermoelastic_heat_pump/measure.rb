#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class ThermoelasticHeatPump < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ThermoelasticHeatPump"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end
    
    require 'json'
    
    results = {}
    dx_name = []
    #get all DX coils in model
    dx_single = model.getCoilCoolingDXSingleSpeeds 
    dx_two = model.getCoilCoolingDXTwoSpeeds
    dx_heat = model.getCoilHeatingDXSingleSpeeds
    
    if !dx_single.empty?
      dx_single.each do |dx|
        runner.registerInfo("DX coil: #{dx.name.get} Initial COP: #{dx.ratedCOP.get}")
        dx.setRatedCOP(OpenStudio::OptionalDouble.new(6.0))
        runner.registerInfo("DX coil: #{dx.name.get} Final COP: #{dx.ratedCOP.get}")
        dx_name << dx.name.get
      end
    end
    if !dx_two.empty?
      dx_two.each do |dx|
        runner.registerInfo("DX coil: #{dx.name.get} Initial High COP: #{dx.ratedHighSpeedCOP.get} Low COP: #{dx.ratedLowSpeedCOP.get}")
        dx.setRatedHighSpeedCOP(6.0)
        dx.setRatedLowSpeedCOP(6.0)
        runner.registerInfo("DX coil: #{dx.name.get} Final High COP: #{dx.ratedHighSpeedCOP.get} Final COP: #{dx.ratedLowSpeedCOP.get}")
        dx_name << dx.name.get
      end
    end
    if !dx_heat.empty?
      dx_heat.each do |dx|
        runner.registerInfo("DX coil: #{dx.name.get} Initial COP: #{dx.ratedCOP}")
        dx.setRatedCOP(6.0)
        runner.registerInfo("DX coil: #{dx.name.get} Final COP: #{dx.ratedCOP}")
        dx_name << dx.name.get
      end
    end
       
    if dx_name.empty?
       runner.registerWarning("No DX coils are appropriate for this measure")
       runner.registerAsNotApplicable("No DX coils are appropriate for this measure")
    end
     
    #unique initial conditions based on
    runner.registerInitialCondition("The building has #{dx_name.size} DX coils for which this measure is applicable.")

    #reporting final condition of model
    runner.registerFinalCondition("The COP of the following coils was increased to 6: #{dx_name}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ThermoelasticHeatPump.new.registerWithApplication