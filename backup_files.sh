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

function checkSpace() {
    local srcDir="$1"
    local destDir="$2"

    # Calcula o tamanho total do diretório de origem em bytes
    local srcSize=$(du -sb "$srcDir" 2>/dev/null | awk '{print $1}') # awk '{print $1}' isto é para não nos
    
    if [ -z "$srcSize" ]; then  
        # passar informação desnecessaria
        echo "Error: Unable to calculate the size of the source directory. Exiting."
        
        exit 1
    fi

    # Obtém o espaço disponível no destino em bytes
    local availableSpace=$(df -B1 "$destDir" | tail -1 | awk '{print $4}') # o mesmo que em cima
    if [ -z "$availableSpace" ]; then
        
        echo "Error: Unable to determine available space on the destination. Exiting."
        
        exit 1
    fi

    # Compara o espaço disponível com o tamanho do diretório de origem
    if [ "$availableSpace" -ge "$srcSize" ]; then

        return 0

    else
        echo "Warning: Not enough space for the backup."
        echo "Source size: $((srcSize / 1024 / 1024)) MB, Available space: $((availableSpace / 1024 / 1024)) MB"
        return 1
    fi
}

function accsBackup(){
    local pathtoDir="$1"
    local backupDir="$2"

    # Cria o diretório de backup se ele não existir e se não estiver no modo de verificação
    if [ ! -d "$backupDir" ]; then

        checkModeM mkdir -p "$backupDir"
    
    fi

    # Verifica se há espaço suficiente no destino
    if [ "$checkMode" = false ]; then
        if ! checkSpace "$pathtoDir" "$backupDir"; then

            echo "Error: Insufficient space on backup directory. Exiting."

            exit 1
        fi
    fi

    for file in $pathtoDir/*;do

        backup_file="$backupDir/$(basename "$file")";

        if [ -f "$backup_file" ]; then

            date_file=$(ls -l "$file" | awk '{print $6}');

            backup_date=$(ls -l "$backup_file" | awk '{print $6}');
        
            if [ "$date_file" != "$backup_date" ]; then

                checkModeM cp -a "$file" "$backupDir";

                echo "cp -a $file $backupDir";

            fi
        elif [ -f "$file" ]; then
        
            checkModeM cp -a "$file" "$backupDir";

            echo "cp -a $file $backupDir";
        fi

    done
 
}
accsBackup "$pathtoDir" "$backupDir";