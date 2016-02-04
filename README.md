# Overview

This project was developed for the [Building Technologies Office at the U.S. Department of Energy](http://energy.gov/eere/buildings/building-technologies-office).  The goal was to create an analysis platform that enables the program to compare different technologies on an equal footing using identical assumptions about the building stock.

The approach was to use [OpenStudio](https://www.openstudio.net/) to run energy simulations of the [DOE Commercial Prototype Building Models](http://www.energycodes.gov/commercial-prototype-building-models) and [DOE Commercial Reference Buildings](http://energy.gov/eere/buildings/commercial-reference-buildings) with and without different technologies applied to estimate savings.  Each technology is applied to the models through an [OpenStudio Measure](http://nrel.github.io/OpenStudio-user-documentation/getting_started/about_measures/).

This analysis is designed to be updated as the building stock and technology changes.  If you review the assumptions and find something that does not make sense, at a minimum, please report the issue [on the issues page](https://github.com/NREL/OpenStudio-PTool/issues).  If you have a proposed solution, you can install the code (instructions below), make modifications, and run the analysis yourself to review your changes.  

## Reviewing the assumptions

### Building stock models

The starting points for the analysis are the OpenStudio versions of the the [DOE Commercial Prototype Building Models](http://www.energycodes.gov/commercial-prototype-building-models) and [DOE Commercial Reference Buildings](http://energy.gov/eere/buildings/commercial-reference-buildings).  These are detailed energy models that represent buildings common in the U.S. building stock.  Their respective sites link to extensive background information.

### Technology assumptions

The `design_docs` directory contains Word documents that describe each technology (Measure) and its assumptions at a high level.  This should be sufficient to get a general understanding of the assumptions being made.

The `measures` directory contains a series of subdirectories for each technology (Measure) in the analysis.  The `measure.rb` file contains the actual logic used to modify the energy model.  Because each Measure is self-contained, it may be updated without an understanding of how the entire analysis infrastructure works.

## Installation instructions

1. Install the [latest version of OpenStudio](https://www.openstudio.net/downloads)
2. **On Windows**, install {http://rubyinstaller.org/ Ruby 2.0} (`ruby -v` from command prompt to check installed version).  
3. **On Mac** Ruby 2.0 is already installed.
4. Connect Ruby to OpenStudio:
	1. **On Mac**:
	2. Create a file called `openstudio.rb`
	3. Contents: `require "/Applications/OpenStudio\ 1.9.0/Ruby/openstudio.rb"` Modify `1.9.0` to the version you installed.
	4. Save it here: `/usr/lib/ruby/site_ruby/openstudio.rb`
	5. **On Windows**:
	6. Create a file called `openstudio.rb`
	7. Contents: `require "C:/Program Files/OpenStudio 1.9.3/Ruby/openstudio.rb"`  Modify `1.9.0` to the version you installed.
	8. Save it here: `C:/MyRuby200/lib/ruby/site_ruby/openstudio.rb`

5. Install the `bundler` ruby gem. (`gem install bundler` from command prompt)
6. Install [Git](https://git-scm.com), a tool used to download source .
7. Clone or download the [OpenStudio Standards Project source code](https://github.com/NREL/openstudio-standards/archive/master.zip).
8. Clone or download the [OpenStudio PTool Project source code](https://github.com/NREL/OpenStudio-PTool/archive/master.zip).
9. The source code should be placed in the same parent folder (folder names matter)
  - C:/Somewhere/OpenStudio-PTool
  - C:/Somewhere/openstudio-standards
9. **On Windows**, use the Git Bash instead of the default command prompt.
10. **On Mac** the default terminal is fine.
11. In Git Bash/terminal, navigate to the `/OpenStudio-PTool` directory.
12. In Git Bash/terminal: `bundle install`.
13. This analysis is run on the cloud.  Create an [Amazon AWS account](http://aws.amazon.com/).  This requires a credit card.
14. From your Amazon AWS account, create an access key and secret key and copy/paste to a text file somewhere on your computer.  **Do not lose these keys because you only get these keys once!**
15. The first time you run an analysis, you will need to enter these keys into the `C:/Users/username/aws_config.yml` file.

  
## Running the analysis

In the Git Bash/terminal: 

1. Navigate to the `/OpenStudio-PTool` directory.
2. `rake run`
3. Type the number of the analysis you want to run, ENTER
4. If this is your first run, enter your AWS keys into `C:/Users/username/aws_config.yml`
5. After the analysis starts, you will get a URL.  Go to this URL in a web browser.
6. Open your [Amazon AWS Console](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1)
7. Make sure you are in the **N. Virginia** region (dropdown in upper right corner).
8. Click Instances in the left column.  This will show you all the servers and workers that are running.
9. To get the URL of the server, click on the server and the URL shows up toward the bottom.  You can copy/paste this into a browser.  This is the same URL that showed up in the terminal.
10. **Important:  after you finish running the analysis and downloading the results, make sure you go to your [Amazon AWS Console](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1) and Terminate any running instances.  Amazon charges by the hour, and you will be charged until you shut them down.  NREL and DOE are not responsible for any charges you may incur.** To terminate instances, click Instances, check them, right click > instance state > terminate (ok).
  
## Looking at the results

1. In your web browser, click on the name of your analysis
2. You will see a list of the simulations being run.  Refresh the page occasionally to check the status.
3. You can click on an individual simulation to see more details about the run, including which Measures were applied (1 = measure was applied).
4. After all simulations complete, click on the `CSV` files in the `Downloads` section at the top right of the page.
5. Use your data processing tool of choice to parse the results. The `data_processing` folder contains some examples that may be useful. Typically, savings are calculated by finding a run with a particular building type/climate zone/vintage combination, then comparing that to the same combination with one Measure applied.  
6.  **Important:  after you finish running the analysis and downloading the results, make sure you go to your [Amazon AWS Console](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1) and Terminate any running instances.  Amazon charges by the hour, and you will be charged until you shut them down.  NREL and DOE are not responsible for any charges you may incur.** To terminate instances, click Instances, check them, right click > instance state > terminate (ok).

## Modifying this for your own needs

Running large-scale energy modeling analyses can be difficult because of the overhead required to set up and maintain the insfrastructure.  However, the [OpenStudio Analysis Spreadsheet](https://github.com/NREL/OpenStudio-analysis-spreadsheet), which the PTool project is based on, makes this process much easier.  If you want to modify this project for your own analysis, we suggest the following approach.

1. Read the README for the [OpenStudio Analysis Spreadsheet](https://github.com/NREL/OpenStudio-analysis-spreadsheet) to get a general overview of the possibilities.
2. Read the [documentation on how the spreadsheet is structured](https://github.com/NREL/OpenStudio-analysis-spreadsheet/raw/develop/documentation/spreadsheet_userguide_prerelease.pdf).
3. Fork the [OpenStudio-PTool Repository](https://github.com/NREL/OpenStudio-PTool).
4. Modify the Measures in the `measures` directory.
5. Run your own large-scale analysis!

## Troubleshooting

### AWS

#### New account verification

If you just created your Amazon Web Service account and try to run the analysis, you may notice an error regarding verification of the account (see below).

```
Aws::EC2::Errors::PendingVerification: Your account is currently being verified. 
Verification normally takes less than 2 hours. Until your account is verified, 
you may not be able to launch additional instances or create additional volumes. 
If you are still receiving this message after more than 2 hours, please let us 
know by writing to aws-verification@amazon.com. We appreciate your patience.
```

If this happens, wait a couple hours and try again.  You can also contact Amazon to check if they have verified your account.

#### New account instance limits exceeded

When you first create an Amazon AWS Account, Amazon temporarily limits the number of instance you can enable.  This is automatically increased [to these  normal limits](http://aws.amazon.com/ec2/faqs/#How_many_instances_can_I_run_in_Amazon_EC2) after some amount of time (a day or two?).  You can view your current limits (**OS only uses the N. Virginia region**) by [following these instructions](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-resource-limits.html). Contact Amazon if the limit doesn't increase after a few days.

