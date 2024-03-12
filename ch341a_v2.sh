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
# Print_var
# Splash_Screen
# Multichip
# Bus_Select
# Execute
#
	    
	  
# Function : Print_var
# ---------------------------------------------------------
# This function prints out the value of the four variables
# used to determinate the flow of the script
# CHIP
# BUS 
# OPERATION 
# FILENAME  
# CHOICE    
function Print_var
       {
		echo "Current variables values "
		echo "----------------------------------------"
		echo "CHIP      = $CHIP"
		echo "BUS       = $BUS"
		echo "OPERATION = $OPERATION"
		echo "FILENAME  = $FILENAME"
		echo "CHOICE    = $CHOICE"
	    echo " "
	    }

# Function : Splash_Screen
# ---------------------------------------------------------
# This function display a starting splash screen
# with some informations, and checks for warnings

function Splash_Screen
       {
        # Is dialog available?
        if ! command -v dialog >/dev/null 2>&1; then 
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
          dialog --no-lines --colors --timeout 5 --backtitle "WARNING! WARNING! WARNING! " --msgbox "\Z1  Flashrom not found \n\n  SPI functionality not available" 0 0
          F_VERSION="flashrom N/A "
         else 
           F_VERSION=$(flashrom --version | sed -n 1p | awk '{print $1" " $2 }')
        fi  
        
        #Is ch341eeprom available? If yes -> Get Version
        if ! command -v ch341eeprom >/dev/null 2>&1; then 
          dialog --no-lines --colors --timeout 5 --backtitle "WARNING! WARNING! WARNING! " --msgbox "\Z1  ch341eeprom not found \n\n  I2C functionality not available" 0 0
           C_VERSION="ch341eeprom N/A "
         else
           C_VERSION=$(ch341eeprom 2>&1| sed -n 2p | awk '{print $1" " $2 }')
           C_VERSION="ch341eeprom ${C_VERSION}"      
        fi  
        
        # Display splash screen
        dialog --no-lines --timeout 3 --msgbox  "        ----- ch341a.sh ----- \n      -------------------------\n\nSimple shell script to simplify the \nuse of the CH341A programmer  \n\n percoco2000@gmail.com\n\nProgrammer $FOUND found\n$F_VERSION \n$C_VERSION" 16 42 
        
        }
        
# Function : Multichip
# ---------------------------------------------------------
# When multiple id chip detected this function ask the 
# user to choose the correct CHIP from a dinamically 
# generated dialog menu.
# At first an array containing all the selectable chip is
# generated from the flashrom output. Because the dialog menu
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
        
        # The menu   
        CHIP=$(dialog --nocancel \
                      --backtitle " Warning Multiple chip ID detected" \
                      --title "Select proper CHIP"\
                      --default-item '1' \
                      --menu "Select:" 12 35 5 \
                        "${temparray[@]}" \
                      --output-fd 1)
                     
        
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
        BUS=$(dialog --nocancel \
                     --backtitle "$BTITLE" \
                     --title "Bus"\
                     --default-item $BUS \
                     --menu "Select:" 10 25 3 \
                            spi "25Qxx EEprom  " \
                            i2c "24Cxx EEprom  " \
                     --output-fd 1)
  
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
		    
		    i2c)
		        CHIP=$(dialog --nocancel \
                --backtitle "Current chip : $CHIP" \
                --title "Select"\
                --default-item $CHIP \
                --menu "EEprom : " 15 20 8\
                  24c01 ""\
                  24c02 ""\
                  24c04 ""\
                  24c08 ""\
                  24c16 ""\
                  24c32 ""\
                  24c64 ""\
                  24c128 ""\
                  24c256 ""\
                  24c512 ""\
                  24c1024 ""\
                --output-fd 1)  
                ;;
             spi)
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
	                   dialog --title "Warning " \
	                   --no-label "Exit" \
	                   --yes-label "Retry" \
	                   --yesno 'Programmer not detected \n check and retry' \
	                    8 30
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
	       spi)
	          if command -v flashrom >/dev/null 2>&1; then

	           	                
	           # if no chip is detected alert the user and give chioce to check or exit 
	           while [ "$CHIP" == "Unknown" ]
	               do
	                dialog --title "Warning " \
	                --no-label "Exit" \
	                --yes-label "Retry" \
	                --yesno 'No chip detected, check the programmer and retry' \
	                8 30
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
	                  write)
	                       echo " -----  Programming spi ----- "
	                       echo " "
	                       
	                       flashrom -p ch341a_spi -c $CHIP -w $FILENAME
	                       
	                       retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         Print_var
	                         echo "Press any key to exit"
	                         read -s -n 1
	                         exit 1
	                       else
	                         sleep 2
	                         dialog --no-lines --timeout 10 --msgbox " DONE! " 0 0
	                       fi
	                       ;;
	                  
	                  read)
	                       echo " ----- Reading spi -----"
	                       echo " "
	                     
	                       flashrom -p ch341a_spi -c $CHIP -r $FILENAME 
	                     
	                       retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         Print_var
	                         echo "Press any key to exit"
	                         read -s -n 1
	                         exit 1
	                       else
	                         sleep 2
	                         dialog --no-lines --timeout 10 --msgbox " DONE! " 0 0
	                       fi
	                       ;;     
	               esac
	                      
	          else 
	               dialog --no-lines \
	                      --colors   \
	                      --backtitle "\Z1Critical Error" \
	                      --infobox  "You need flashrom to execute this task\n\nSee https://www.flashrom.org" 0 0
                 
	               
	               exit 1
	          fi
           ;;
    
           i2c)
              if command -v ch341eeprom >/dev/null 2>&1; then
               case "$OPERATION" in
	              write)
	                   echo " ----- Programming I2C ----- "
	                   echo " "
	                   
	                   ch341eeprom -s $CHIP -w $FILENAME
                       
                       retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         Print_var
	                         echo "Press any key to exit"
	                         read -s -n 1
	                         exit 1
	                       else
	                         sleep 2
	                         dialog --no-lines --timeout 10 --msgbox " DONE! " 0 0
	                       fi
	                   ;;
	              
	              read)
	                   echo " ----- Reading I2C ----- "
	                   echo " "
	                   ch341eeprom -s $CHIP -r $FILENAME
	                   
	                   retval=$?
	                       if [ $retval -ne 0 ]; then 
	                         echo "Something went wrong ........"
	                         Print_var
	                         echo "Press any key to exit"
	                         read -s -n 1
	                         exit 1
	                       else
	                         sleep 2
	                         dialog --no-lines --timeout 10 --msgbox " DONE! " 0 0
	                       fi
	                   ;; 
	           esac
              else
                 dialog --no-lines \
	                    --colors   \
	                    --backtitle "\Z1Critical Error" \ 
	                    --infobox  "You need ch341eeprom to execute this task\n\nSee https://github.com/commandtab/ch341eeprom" 0 0
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

BTITLE="CH341A Programmer"
CHIP="Unknown"
BUS="spi"
OPERATION="read"
FILENAME=(~/dump.bin)
CHOICE=""


Splash_Screen

Chip_Select
if [ "$CHIP" == "Unknown" ]; then BUS="i2c"; fi

while [ "$CHOICE" != "Exit" ]
	do       
	CHOICE=$(dialog --nocancel \
            --backtitle "$BTITLE" \
            --title "--> Main Menu <--"\
            --default-item 'Prg' \
            --menu "Select:" 14 40 8 \
              Chip "$CHIP EEprom" \
              Bus "$BUS" \
              Action "$OPERATION" \
              File "$FILENAME" \
              Prg "Execute" \
              Exit "Exit" \
            --output-fd 1)
	
	
	case "$CHOICE" in
	       
	       Chip)
	            Chip_Select
	            ;;
	       
	       Bus)
	            Bus_Select
	            Chip_Select
	            ;;     
	       
	       Action)
                OPERATION=$(dialog --nocancel \
                            --backtitle "Chip detected : $CHIP" \
                            --title "Operation"\
                            --default-item '1' \
                            --menu "Select:" 10 25 3 \
                              read "EEprom" \
                              write "EEprom" \
                            --output-fd 1)
                ;;
                        
	       File)
	           TEMPFILE=$(dialog --output-fd 1 --nocancel --title "Move with TAB-select with Spacebar-Up one dit with BKSPC"  --fselect $HOME/ 8 60)
	           exitstatus=$?
	           if [ $exitstatus -ne "255" ]; then FILENAME=$TEMPFILE; fi
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
	     



