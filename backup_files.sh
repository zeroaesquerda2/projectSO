#!/bin/bash

checkMode=false;

while getopts ":c" opt; do
case ${opt} in

    c)
        # Ativa o modo de verificação (check mode)
        checkMode=true;

    ;;

    ?)
        # Exibe mensagem de erro para opções inválidas
        echo "Invalid option: -${OPTARG}."

        exit 1

    ;;

esac
done

function checkModeM(){

    if [ $checkMode = false ]; then

        "$@";

    fi

}

shift $((OPTIND - 1))

pathtoDir="$1";
backupDir="$2";

if [ ! -d "$pathtoDir" ]; then

    echo "Error: Work Directory '$pathtoDir' doesn't exist."

    exit 1

fi

function accsBackup(){

    if [ ! -d "$backupDir" ]; then

        echo "Creating Backup Directory"

        checkModeM mkdir -p $backupDir;

        echo "mkdir -p $backupDir";
    
    else
    
        echo "Backup Directory Exists";
    
    fi

    if [ find $backupDir -empty -type d ]; then
        
        checkModeM cp -a $pathtoDir/. $backupDir;

        echo "cp -a $pathtoDir/. $backupDir";

    else
        checkModeM ls -l $pathtoDir;

        checkModeM ls -l $backupDir;

        for file in $pathtoDir/*;do

            backup_file="$backupDir/$(basename "$file")";

            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');
            
                if [ "$date_file" = "$backup_date" ]; then

                    echo "File $(basename "$file") is up-to-date."

                else

                    echo "File $(basename "$file") has a different modification date in the backup.";

                    checkModeM cp -a "$file" $backupDir;

                    echo "cp -a $file $backupDir";

                fi
            else
                echo "File $(basename "$file") is missing in the backup.Let's add it to the backup.";

                checkModeM cp -a "$file" $backupDir;

                echo "cp -a $file $backupDir";
            fi

        done

    fi
}
accsBackup;