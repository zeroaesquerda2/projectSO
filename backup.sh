#!/bin/bash

#echo "What's the path to the Backup Directory?"
#read backupDir
#echo "What's the path to the Directory that you want to backup? (it can only have files)"
#read backupDir

backupDir="/home/marta/Backup";
pathtoDir="/home/marta/TESTEPROJ";

function accsBackup(){

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
    
        echo "Backup Directory Already Exists";
    
    fi

    ###

    if find $backupDir -empty -type d; then
        
        cp -a $pathtoDir/. $backupDir;

        echo "cp -a $pathtoDir/. $backupDir";

    else

        echo "Files that are in the Directory we want to backup";

        ls -l $pathtoDir;

        echo "Files in the Backup Directory";

        ls -l $backupDir;

        RecursiveDir;

    fi
}

function RecursiveDir(){

    for file in $pathtoDir/*; do

            backup_file="$backupDir/$(basename "$file")";
            
            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');
            
                if [ "$date_file" = "$backup_date" ]; then

                    echo "File $(basename "$file") is up-to-date."

                else

                    echo "File $(basename "$file") has a different modification date.";

                    cp -a "$file" $backupDir;

                    echo "cp -a "$file" $backupDir" ;

                fi

            elif [ -d "$file" ]; then

                cp -a "$file" $backupDir;

                echo "cp -a "$file" $backupDir" ;

                RecursiveDir "$file" "$backup_file";

            else

                echo "File $(basename "$file") is missing. Let's add it to the backup.";

                cp -a "$file" $backupDir;

                echo "cp -a "$file" $backupDir" ;
            fi

    done
}

accsBackup;
