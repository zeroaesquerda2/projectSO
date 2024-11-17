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

# Esta função verifica se existe espaço suficiente na diretoria destino
function checkSpace() {
    local srcDir="$1"
    local destDir="$2"

    # Cria o diretório de destino caso não exista
    if [ ! -d "$destDir" ]; then
        echo "Creating backup directory: $destDir"
        mkdir -p "$destDir"
    fi

    # Calcula o tamanho total do diretório de origem em bytes
    local srcSize=$(du -sb "$srcDir" 2>/dev/null | awk '{print $1}') # awk '{print $1}' isto é para não nos
    if [ -z "$srcSize" ]; then                                       # passar informação desnecessaria
        
        echo "Error: Unable to calculate the size of the source directory. Exiting."
        
        exit 1
    fi

    # Obtém o espaço disponível no destino em bytes
    #local availableSpace=$(stat -f --format="%a*%s" "$destDir" | bc) # alternativa ao df
    local availableSpace=$(df -B1 "$destDir" 2>/dev/null | tail -1 | awk '{print $4}') # o mesmo que em cima
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

     if ! checkSpace "$pathtoDir" "$backupDir"; then

        echo "Error: Insuficient space on backup directory. Exiting."

        exit 1
    fi

    if [ ! -d "$backupDir" ]; then

        checkModeM mkdir -p "$backupDir";
    
    fi

    if [ ! "$(ls -A $backupDir)" ]; then
        
        checkModeM cp -a "$pathtoDir"/. "$backupDir";

        echo "cp -a $pathtoDir/. $backupDir";

    else
        checkModeM ls -l $pathtoDir;

        checkModeM ls -l $backupDir;

        for file in $pathtoDir/*;do

            backup_file="$backupDir/$(basename "$file")";

            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');
            
                if [ "$date_file" != "$backup_date" ]; then

                    checkModeM cp -a "$file" "$backupDir";

                    echo "cp -a $file $backupDir";

                fi
            else
                checkModeM cp -a "$file" "$backupDir";

                echo "cp -a $file $backupDir";
            fi

        done

    fi
}
accsBackup;