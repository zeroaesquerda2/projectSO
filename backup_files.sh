#!/bin/bash

function accsBackup(){
    #echo "What's the path to the Backup Directory?"
    #read backupDir
    #echo "What's the path to the Directory that you want to backup? (it can only have files)"
    #read backupDir

    backupDir="/home/marta/Backup";
    pathtoDir="/home/marta/TESTEPROJ";

    #user=$(whoami);                         #Várias maneiras de colocar!!
    #backupDir="/home/${user}/Backup";

    if [ ! -d "$backupDir" ]; then

        echo "Creating Backup Directory"

        mkdir -p $backupDir;

        echo "mkdir -p $backupDir";

        lastDate=$(date +'%Y%m%d_%H%M%S');

        backupFilename="backup_${lastDate}.tar.gz";

        tar czf "${backupDir}/${backupFilename}" $pathtoDir;

        tar -tzf "${backupDir}/${backupFilename}"

        echo "Backup created: ${backupDir}/${backupFilename}";
    
    else
    
        echo "Backup Directory Exists";
    
    fi

    if [ find $backupDir -empty -type d ]; then
        
        cp -a $pathtoDir/. $backupDir;

        echo "cp -a $pathtoDir/. $backupDir";

    else
        ls -l $pathtoDir;

        ls -l $backupDir;

        for file in $pathtoDir/*;do

            backup_file="$backupDir/$(basename "$file")";

            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');
            
                if [ "$date_file" = "$backup_date" ]; then

                    echo "File $(basename "$file") is up-to-date."

                else

                    echo "File $(basename "$file") has a different modification date in the backup.";

                    cp -a "$file" $backupDir;

                fi
            else
                echo "File $(basename "$file") is missing in the backup.Let's add it to the backup.";

                cp -a "$file" $backupDir;
            fi

        done

    fi
}
accsBackup;