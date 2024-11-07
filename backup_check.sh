#!/bin/bash

# Diretórios de origem e backup
srcDir="$1"
backupDir="$2"

#  Ver se foram passados dois argumentos
if (( $# < 2 )); then
    echo "Not enough arguments were given!"
    exit 1
fi

# Verifica se os diretórios existem
if [ ! -d "$srcDir" ]; then # source
    echo "Error: Source directory '$srcDir' does not exist."
    exit 1
fi

if [ ! -d "$backupDir" ]; then # backup
    echo "Error: Backup directory '$backupDir' does not exist."
    exit 1
fi

# funcao principal da comparacao
function filesCheck() {
    local srcDir="$1"
    local backupDir="$2"

    for file in "$srcDir"/*; do
        fileName=$(basename "$file")
        backupPath="$backupDir/$fileName"

        # verifica se o ficheiro e regular ou uma diretoria
        if [ -f "$file" ]; then
            # verifica se o ficheiro existe no backup 
            if [ -f "$backupPath" ]; then
                # extrai o codigo hash do ficheiro e da copia no backup
                fileHash=$(md5sum "$file" | awk '{print $1}')
                backupHash=$(md5sum "$backupPath" | awk '{print $1}')
                
                # no caso de serem diferentes diferentes
                if [ "$fileHash" != "$backupHash" ]; then
                    echo "$srcDir/$fileName $backupDir/$fileName differ."
                fi
            # se nao houver copia no backup
            else
                echo "The file '$fileName' doesn't have a backup or its name might have been changed."
            fi
        # no caso de "file" ser uma diretoria
        elif [ -d "$file" ]; then
            if [ -d "$backupPath" ]; then
                # recursividade com as novas diretorias
                filesCheck "$file" "$backupPath"
            fi
        fi
    done
}

# chamada da funcao
filesCheck "$srcDir" "$backupDir" 

# desculpa isto e teclado ingles e nao tem acentos nem cedilha