Silverlab AOL microscope controller
========

Welcome!

This is the home of the SilverLab MatLab Imaging Software, an open-source application for controlling an Acousto-Optic Lens laser scanning microscope

This MATLAB toolbox is a project aiming at easing the development of the Silverlab AOL microscope. It includes the drivers generating the ramps (AOL ramps) and various tools required for hardware communication, data collection and analysis. The AOL drivers are shared with the open source LabView acquisition system and constitute an independent module. The other parts of the code are not required by LabView, but some functions can be called from another environment (eg. LabView).

The code contains modules for data acquisition, and for data analysis. A GUI was developed to help performing more complex experiments, but all function can work in command lines, enabling scripting. Most data analysis function can be used without using the entire acquisition environment.

The code was mostly developed and tested in the Windows 10/11 environment with MATLAB 2017b (for acquisition) and  MATLAB 2021a (for offline analysis), although some efforts were made to make it work with mac OS, it hasn't been tested recently and it there would probably be a few days of work to fix it. A few features require some compiled c code or NI dlls (if you want to load *tdms* files) and cannot currently work with mac.

# Documentation

The documentation is under development. You will find different documentation sources

* The function header usually describe the function role and provides some example. 
* demo scripts are available to demonstrate specific features. They are either regular MATLAB scripts or Live scripts. You will find some in ./utilities/demo_scripts
* The ./docs/ subfolder contains various documentation files

Please open an issue if you have any specific request

# Future Developments

A lot of features are under development in our lab and our partners labs, although they are still under testing. Many features, including a GUI will be published soon, but you can contact the developers if you need more information.


# Other Resources

You can find our lab resources and documentation [here](https://github.com/SilverLabUCL/SilverLab-Microscope) or on our [lab website](https://silverlab.org/), or contact us (a.silver@ucl.ac.uk)

