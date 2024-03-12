#!/bin/bash
# # ch341.sh
# ----------------------------------------
# a simple bash script that control a CH341 based programmer
# using dialog and 2 linux tools:
# flashrom    --> for SPI eeproms  www.flasrom.com
# ch341eeprom --> for I2C eeproms  https://github.com/commandtab/ch341eeprom
#
# Developed by percoco2000 ( percoco2000@gmail.com )



# Functions used
#------------------------------------------------------------
#
# Splash_Screen
# Multichip
# Bus_Select
# Chip_Select
# Execute
#
	    
	    
# Function : Splash_Screen
# ---------------------------------------------------------
# This function display a starting splash screen
# with some informations, and checks for warnings

function Splash_Screen
       {
        # Is Xdialog available?
        if ! command -v ./Xdialog >/dev/null 2>&1; then 
          clear
          echo "     -----  Critical Error!!  ----- " 
          echo " -------------------------------------- "
          echo " dialog not found."
          echo " this script cannot work without"
          exit 1
        fi  
                
        # Is programmer properly detected?
        FOUND="CH341A"
        if [ "`lsusb | grep CH341`" == "" ]; then FOUND="not"; fi
        
        
        # Is flashrom available? If yes -> Get Version
        if ! command -v flashrom >/dev/null 2>&1; then 
          ./Xdialog --title "$TITLE" --timeout 5 --backtitle "WARNING! WARNING! WARNING! " --msgbox "  Flashrom not found \n\n  SPI functionality not available" 0 0
          F_VERSION="flashrom N/A "
         else 
           F_VERSION=$(flashrom --version | sed -n 1p | awk '{print $1" " $2 }')
        fi  
        
        #Is ch341eeprom available? If yes -> Get Version
        if ! command -v ch341eeprom >/dev/null 2>&1; then 
          ./Xdialog --title "$TITLE" --timeout 5 --backtitle "WARNING! WARNING! WARNING! " --msgbox "  ch341eeprom not found \n\n  I2C functionality not available" 0 0
           C_VERSION="ch341eeprom N/A "
         else
           C_VERSION=$(ch341eeprom 2>&1| sed -n 2p | awk '{print $1" " $2 }')
           C_VERSION="ch341eeprom ${C_VERSION}"      
        fi  
        
        # Display splash screen
        ./Xdialog --title "$TITLE" --timeout 3 --left --msgbox  "     -----  ch341a.sh  ----- \n    ---------------------------\n\nSimple shell script to simplify the \nuse of the CH341A programmer  \n\n percoco2000@gmail.com\n\nProgrammer $FOUND found\n$F_VERSION \n$C_VERSION " 20 62
        
        }
        
# Function : Multichip
# ---------------------------------------------------------
# When multiple id chip detected this function ask the 
# user to choose the correct CHIP from a dinamically 
# generated dialog menu.
# At first an array containing all the selectable chip is
# generated from the flashrom output. Because the Xdialog menu
# requests for every item in the list two labels (one is the 
# choice, the other a descriptio) in the form:
# "choice1" "description1"  "choice2" "description2"....
# an interlaved array (temparray) is generated, in the form of:
# temparray[0]="choice1" 
# temparray[1]="description1"
# temparray[2]="choice2"
# temparray[3]="description2"....
# trimming the " " from the strings
# A menu is then displayed and the user can choose the correct
# value for CHIP.

function Multichip
       {
 		# Read from flashrom the chips with same ID
 		CHIP=$(flashrom -p ch341a_spi | grep "Multiple flash" | awk '{print substr($0,60)}')
        
        # temporally change the value for IFS to create the chips array
        [ -v IFS ] && oldIFS="$IFS" || unset oldIFS
        
        # Here comma is our delimiter value
        IFS="," 
        # create the array
        read -a myarray <<< $CHIP
        # Restore IFS 
        [ -v oldIFS ] && IFS="$oldIFS" || unset IFS
        
        # Create the interlaved array -> temparray
        j=0
        for i in ${myarray[@]}
          do
           temparray[$(($j*2))]=$(echo $i | tail --bytes=+2 | head -c -2)
           temparray[(($j*2+1))]=""
           ((j++))
        done
        echo ${temparray[1]}
        # The menu   
        CHIP=$(./Xdialog --no-cancel \
                         --no-close \
                         --backtitle "Multiple chip ID detected" \
                         --title "$TITLE"\
                         --default-item $temparray[0] \
                         --menu "Select Chip:" 17 45 5 \
                           "${temparray[@]}" \
                         2>&1)
                     
        
        # Unset the two array variables
        unset myarray
        unset temparray
        }
        
        
# Function : Bus_Select
# ---------------------------------------------------------
# This function ask the user which bus to use:
# SPI or
# I2C

function Bus_Select
       {
        # Function 
        BUS=$(./Xdialog --no-cancel \
                        --no-close \
                        --title "$TITLE"\
                        --default-item $BUS \
                        --menu "Select Bus:" 15 40 3 \
                                "SPI" "25Qxx EEprom  " \
                                "I2C" "24Cxx EEprom  " \
                        2>&1)
  
        }


# Function : Chip_Select
# ---------------------------------------------------------
# This function ask the user which EEprom is inserted in
# the programmer. If the bus is set on SPI, it will be 
# autodetected, asking the user only in case of multi ID
# devices.

function Chip_Select
       {
		 case "$BUS" in 
		    
		    I2C)
		        CHIP=$(./Xdialog --no-cancel \
                --no-close \
                --backtitle "Current chip : $CHIP" \
                --title "$TITLE"\
                --menu "Select EEprom : " 20 60 0  \
                  24c01 "128 Bytes" \
                  24c02 "256 Bytes" \
                  24c04 "512 Bytes" \
                  24c08 "1024 Bytes / 1Kb" \
                  24c16 "2048 Bytes / 2Kb" \
                  24c32 "4096 Bytes / 4Kb" \
                  24c64 "8192 Bytes / 8Kb" \
                  24c128 "16384 Bytes / 16Kb" \
                  24c256 "32768 Bytes / 32Kb" \
                  24c512 "65536 Bytes / 64 Kb" \
                  24c1024 "131072 Bytes / 128Kb" \
                2>&1)  
                ;;
             SPI)
                #Detect SPI chip
                CHIP=$(flashrom -p ch341a_spi | grep "Multiple flash chip definitions" )
                if [ "$CHIP" == "" ]; then
                 CHIP=$(flashrom -p ch341a_spi | grep "Found" | cut -d'"' -f 2)
                 if [ "$CHIP" == "" ]; then CHIP="Unknown"; fi 
                 
                 else
                    Multichip
                fi                    
                ;;
            
          esac
        }            


# Function : Execute
# ---------------------------------------------------------
# Function that implement the real operation of the script
# Based on the values of BUS and OPERATION, it choose wich
# software use (ch341eeprom or flashrom) , check for the
# presence of the programmer, and in case of SPI bus, the 
# chip, giving user a chanche to correct issues, or abort. 
# If the software for the operation isn't found, write an 
# error and exit.

function Execute
       {
         # If programmer not detected alert the user and give choice to check or exit
	           if  [ "`lsusb | grep CH341`" == "" ]; then
	           	             while [ "`lsusb | grep CH341`" == "" ]
	                 do
	                   ./Xdialog --title "Warning" \
	                   --ok-label "Retry" \
	                   --cancel-label "Exit" \
	                   --yesno 'Programmer not detected \n check and retry' \
	                    8 32
	                   response=$?
	                   case $response in
	                      0);;
	                      1)exit 1;;
	                      255) exit 1;;
	                   esac    
	             done
	            
	            Chip_Select
	            fi  

  
        case "$BUS" in
	       SPI)
	          if command -v flashrom >/dev/null 2>&1; then

	           	                
	           # if no chip is detected alert the user and give chioce to check or exit 
	           while [ "$CHIP" == "Unknown" ]
	               do
	                ./Xdialog --title "Warning " \
	                --ok-label "Retry" \
	                --cancel-label "Exit" \
	                --yesno 'No chip detected, check the programmer and retry' \
	                8 32
	                response=$?
	                case $response in
	                   0);;
	                   1)exit 1;;
	                   255) exit 1;;
	                esac    
	                Chip_Select
	           done
	      
	               clear
                   
	               case "$OPERATION" in
	                  Write)
	                       echo " -----  Programming spi ----- "
	                       echo " "
	                      
	                       touch /tmp/log.out
	                       ./Xdialog --title "$TITLE" \
	                                 --backtitle "Writing" \
	                                 --no-buttons --no-close \
	                                 --tailbox /tmp/log.out \
	                                   20 90 &
	                       flashrom -p ch341a_spi -c $CHIP -w $FILENAME >>/tmp/log.out  
	                       retval=$?
	                       sleep 1
	                       rm /tmp/log.out
	                      
	                       if [ $retval -ne 0 ]; then 
	                         ./Xdialog --title "$TITLE" \
	                                   --backtitle "ERROR" \
	                                   --left \
	                                   --msgbox "Something went wrong \n Check the output of Flashrom "
	                                   10 35
	                         killall Xdialog          
	                         exit 1
	                       else
	                         sleep 2
	                         killall Xdialog
	                         ./Xdialog --timeout 10 --msgbox " DONE! " 8 30 
	                       fi
	                       ;;
	                  
	                  Read)
	                       echo " ----- Reading SPI -----"
	                       echo " "
	                       
	                       touch /tmp/log.out
	                       ./Xdialog --title "$TITLE" \
	                                 --backtitle "Reading" \
	                                 --no-buttons --no-close \
	                                 --tailbox /tmp/log.out \
	                                   20 90 &
	                       flashrom -p ch341a_spi -c $CHIP -r $FILENAME >>/tmp/log.out  
	                       retval=$?
	                       sleep 1
	                       rm /tmp/log.out
	                       
	                       if [ $retval -ne 0 ]; then 
	                         ./Xdialog --title "$TITLE" \
	                                   --backtitle "ERROR" \
	                                   --left \
	                                   --msgbox "Something went wrong \n Check the output of Flashrom " \
	                                   10 35 
	                         killall Xdialog          
	                         exit 1
	                       else
	                         sleep 2
	                         killall Xdialog
	                         ./Xdialog --timeout 10 --msgbox " DONE! " 8 30
	                       fi
	                       ;;     
	               esac
	                      
	          else 
	               ./Xdialog --title "$TITLE" \
	                         --backtitle "Critical Error" \
	                         --msgbox  "You need flashrom to execute this task\n\nSee https://www.flashrom.org" 0 0
                   exit 1
	          fi
           ;;
    
           I2C)
              if command -v ch341eeprom >/dev/null 2>&1; then
               case "$OPERATION" in
	              Write)
	                   echo " ----- Programming I2C ----- "
	                   echo " "
	                   
	                   ch341eeprom -s $CHIP -w $FILENAME
                       
                       retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         exit 1
	                       else
	                         sleep 2
	                         ./Xdialog --timeout 10 --msgbox " DONE! " 8 30
	                       fi
	                   ;;
	              
	              Read)
	                   echo " ----- Reading I2C ----- "
	                   echo " "
	                   ch341eeprom -s $CHIP -r $FILENAME
	                   
	                   retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         exit 1
	                       else
	                         sleep 2
	                         ./Xdialog --timeout 10 --msgbox " DONE! " 8 30
	                       fi
	                   ;; 
	           esac
              else
                 ./Xdialog --title "$TITLE" \
	                         --backtitle "Critical Error" \
	                         --msgbox  "You need ch341eeprom to execute this task\n\nSee https://github.com/commandtab/ch341eeprom" 0 0
	                    
                 exit 1
             fi           
             ;;
        esac

        }           


#  ------------------------     MAIN LOOP ----------------------------------


# Variables :
# CHIP      --> Chip to read/write
#               For SPI it will be autodetected 
#               For I2C the user has to enter it
# BUS       --> The bus to be used (spi or i2c)
# OPERATION --> read or write
# FILENAME  --> by default ~/dump.bin
# CHOICE    --> User choice in the main menu
#
# with this defaults value the script is set to read an autodetected spi eeprom 

TITLE="CH341A Programmer"
CHIP="Unknown"
BUS="SPI"
OPERATION="Read"
FILENAME=(~/dump.bin)
CHOICE=""


Splash_Screen

Chip_Select
if [ "$CHIP" == "Unknown" ]; then BUS="I2C"; fi

#  Main Menu

while [ "$CHOICE" != "Exit" ]
	do       
	CHOICE=$(./Xdialog --no-cancel \
            --backtitle "--> Main Menu <--" \
            --title "$TITLE" \
            --default-item 'Prg' \
            --menu "Select:" 23 65 8 \
              Chip "$CHIP EEprom" \
              Bus "$BUS" \
              Action "$OPERATION" \
              File "$FILENAME" \
              Prg "Execute" \
              Exit "Exit" \
            2>&1)
	
	exitstatus=$?
	if [ "$exitstatus" -eq "255" ]; then exit 0 ; fi
	
	case "$CHOICE" in
	       
	       Chip)
	            Chip_Select
	            ;;
	       
	       Bus)
	            Bus_Select
	            Chip_Select
	            ;;     
	       
	       Action)
                OPERATION=$(./Xdialog --no-cancel \
                            --no-close \
                            --backtitle "Chip : $CHIP" \
                            --title "$TITLE"\
                            --default-item 'Read' \
                            --menu "Select Action:" 13 45 3 \
                              Read "EEprom" \
                              Write "EEprom" \
                            2>&1)
                ;;
                        
	       File)
	           # Select filename. If no file is choosen or close widget is selected, the filename keep the latest value
	           TEMPFILE=$(./Xdialog --no-cancel --title "Select filename, or enter a new name"  --fselect $HOME/ 8 60 2>&1)
	           exitstatus=$?
	           if [[ "$exitstatus" -ne "255"  &&  "$TEMPFILE" != "" ]]; then FILENAME=$TEMPFILE; fi
	           unset TEMPFILE
	           unset exitstatus
	            ;;
	       
	       Prg)
	            clear
	            Execute $BUS $OPERATION $FILENAME $CHIP
	            ;;     
	esac
    
done
clear
exit 0
	     



