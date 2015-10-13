# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class AddEconomizerDamperLeakage < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add Economizer Damper Leakage"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) changes the minimum outdoor air flow requirement of all Controller:OutdoorAir objects attached to all AirLoops present in a model to represent a value equal to a continuous 10% of outdoor air flow damper leakage condition . For cases where the outdoor air controller is not configured for airside economizer operation, the measure calculates and assigns a minimum outdoor airflow rate value equal to 10% of the calculated system minimum outdoor air flow rate.  For cases of controllers capable of airside economizer operation,  the measure calculates and assigns a minimum outdoor airflow rate value equal to 10% of the calculated system maximum outdoor air flow rate.  For both cases, outdoor air damper leakage is set to occur for all hours of the simulation. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure loops through all Controller:OutdoorAir objects present on all air loops in the model. If the Controller Economizer Control Type attribute is set to 'No Economizer', the measure will examine the value for the 'Minimum Outdoor Air Flow Rate' attribute. If it equals = 'Autosize', nothing is changed, If the value for the Minimum Outdoor Flow Rate = 0 then the attribute value is replaced with 'AutoSize'.  An OpenStudio sizing run is executed, and the Autosized value for the Minimum Outdoor Air Flow Rate is retrieved from results. If the Controller Economizer Control Type attribute does not equal 'No Economizer',  the measure will determine whether the MaximumOutdoorAirflowRate is autosized or not. If it is autosized, a sizing run is launched, and the autosized value retrieved. For both cases, a new value for the Minimum Outdoor Air Flow Rate value equal to 10% of the retrieved autosized or hard sized value is set. A schedule maintaining this minimum value for all hours of the year is created and assigned to the airflow is assigned to the field 'Minimum Outdoor Schedule Name'."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the space to add to the model
    space_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("space_name", true)
    space_name.setDisplayName("New space name")
    space_name.setDescription("This name will be used as the name of the new space.")
    args << space_name

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    space_name = runner.getStringArgumentValue("space_name", user_arguments)

    # check the space_name for reasonableness
    if space_name.empty?
      runner.registerError("Empty space name was entered.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # add a new space to the model
    new_space = OpenStudio::Model::Space.new(model)
    new_space.setName(space_name)


    # echo the new space's name back to the user
    runner.registerInfo("Space #{new_space.name} was added.")

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true

  end
  
end

# register the measure to be used by the application
AddEconomizerDamperLeakage.new.registerWithApplication
