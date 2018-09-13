# Voice Manipulator

The Voice Manipulator is a project created in partial fulfillment of the requirements of ECE 492 
(Computer Engineering Design Project) W2013 at the University of Alberta.

The Voice Manipulator allows the user to input a voice signal via microphone and applies various audio 
effects:
* volume adjustment
* echo generation (with and without decay)
* frequency shift

The transformed audio can either be routed directly to speakers, or to an interfaced LM20 Bluetooth 
transceiver.  The LM20 is configured to operate in the hands-free profile, allowing the user to 
send the transformed voice signal over a phone call.

---------------------------------------------------


### Note

The purpose of this repository is only to showcase the source files of this project.  All dependencies 
required to build and reproduce the project are NOT included.

---------------------------------------------------


### Project and Repository Structure

The Voice Manipulator runs on the Altera DE2 development platform, which houses a Cyclone IV FPGA.  A 
soft core (Nios-II) can be implemented on the FPGA.  As such, this project can be divided into hardware 
and software components, with source files being placed in the corresponding directory of this repository.

The `hardware` directory contains files describing the hardware of the system, as follows:
* `ECE492_VM.sopc` - input file for Altera's SOPC Builder, used to connect the system and define non-custom components
* `VoiceManipulator.vhd` - top-level file that specifies how the FPGA is connected to board components
* `echo_generator.vhd` - custom component that handles generation of echo from input audio signal, with selectable delay
* `freq_shifter.vhd` - custom component that implements a Hilbert transform to accomplish a linear frequency shift
* `pcm_interface.vhd` - custom component that translates audio data from the Bluetooth module to a format understandable by the processor
* `sram_controller.vhd` - custom component that handles interfacing between the FPGA and the SRAM component

The `software` directory contains C source-code used to build the executable that runs on the Nios-II implemented 
on the FPGA.
* `main.c` - main executable that defines and runs uCOS tasks
* `samples.h` - contains sine wave table used in frequency shifting

---------------------------------------------------
