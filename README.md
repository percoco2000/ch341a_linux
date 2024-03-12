ch341a.sh This is a bash script that, using dialog, implements a simple gui for the use of ch341a base programmer under linux. It act as a wrapper for 2 other software:

flashrom --> www.flashrom.com ; for SPI operations

ch341eeprom --> https://github.com/command-tab/ch341eeprom for I2C operations

After launch, the script check for the presence of the two softwares and the programmer. Then a menu is displayed with some self explaining choice.

Xch341a is a graphical version of the script using Xdialog
