#!/bin/bash
# Variáveis para armazenar os modos e opções
checkMode=false
tfile=""
regex=""
fileList=()

# Processamento das opções passadas na linha de comando
while getopts ":cb:r:" opt; do
case ${opt} in

    c)
    
        # Ativa o modo de verificação (check mode)
        checkMode=true;

    ;;

    b)
        # Define o ficheiro de exclusão
        tfile="$OPTARG"
        if [ -n "$tfile" ] && [ -f "$tfile" ]; then

            while read -r LINE; do

                if [ -d "$LINE" ]; then

                    fileT $LINE

                fi

                fileList+=("$LINE")

            done < "$tfile"

    fi

    ;;

    r)
        # Define a expressão regular para filtragem de ficheiros
        regex="$OPTARG"

    ;;

    ?)
        # Exibe mensagem de erro para opções inválidas
        echo "Invalid option: -${OPTARG}."

        exit 1

    ;;

    esac
done

function fileT(){
    for file2 in "$1"/*; do
        if [ -d "$file2" ]; then

            fileT "$file2"

        elif [ -f "$file2" ]; then

            fileList+=("$file2")
            
        fi
    done
}

# Função para verificar se um ficheiro deve ser excluído
function fileM() {
    for item in "${fileList[@]}"; do
        if [[ "$1" == "$item" ]]; then
            
            return 1  # O ficheiro está na lista de exclusão

        fi
    done
    return 0
}

# Função para verificar se um ficheiro corresponde à expressão regular
function regexM(){
    if [ -n "$regex" ] && [[ ! "$1" =~ $regex ]]; then

        return 1
    
    fi
    return 0
}

# Função para executar ou apenas exibir comandos com base no modo de verificação.
function checkModeM(){
    if [[ $checkMode == false ]]; then

        "$@"

    fi
}

# Remove as opções processadas da lista de argumentos.
shift $((OPTIND - 1)) 

pathtoDir="$1"
backupDir="$2"

if [ ! -d "$pathtoDir" ]; then

    echo "Error: O diretório de trabalho '$pathtoDir' não existe."

    exit 1

fi

# Função principal para realizar o backup
function accsBackup(){

    # Cria o diretório de backup se ele não existir e se não estiver no modo de verificação
    if [ ! -d "$backupDir" ]; then

        echo "Creating Backup Directory"

        checkModeM mkdir -p "$backupDir"

        echo "mkdir -p $backupDir"
    
    else
    
        echo "Backup Directory Already Exists"
    
    fi

    # Verifica se o diretório de backup está vazio
    if [ ! "$(ls -A $backupDir)" ]; then

            echo "Files that are in the Directory we want to backup"

            checkModeM ls -l $pathtoDir

            Backup "$pathtoDir/." "$backupDir"

    else

        echo "Files that are in the Directory we want to backup"

        checkModeM ls -l $pathtoDir

        echo "Files in the Backup Directory"

        checkModeM ls -l $backupDir

        RecursiveDir "$pathtoDir" "$backupDir"

    fi
}

function Backup(){
    local srcDir="$1"

    local destDir="$2"

    for file in "$srcDir"/*; do

        backupFile="$destDir/$(basename "$file")"

        if ! fileM "$file" ; then

            continue

        fi
        if [ -f "$file" ]; then

            checkModeM cp -a "$file" "$destDir"

            echo "cp -a "$file" $destDir"

        elif [ -d "$file" ]; then

            checkModeM cp -a "$file" "$destDir"

            echo "cp -a $file $destDir" 

            Backup "$file" "$backupFile"
        fi
    done
}
# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){
    for file in $pathtoDir/*; do

        backup_file="$backupDir/$(basename "$file")"

        if ! fileM "$file" ; then
            continue
        fi
        
        if [ -f "$backup_file" ]; then

            date_file=$(ls -l "$file" | awk '{print $6}')

            backup_date=$(ls -l "$backup_file" | awk '{print $6}')

            if [ "$date_file" == "$backup_date" ]; then

                echo "File $(basename "$file") is up-to-date."

            else

                echo "File $(basename "$file") has a different modification date."

                checkModeM cp -a "$file" "$backupDir"

                echo "cp -a "$file" $backupDir" 

            fi

        elif [ -d "$file" ]; then

                checkModeM cp -a "$file" "$backupDir"

                echo "cp -a $file $backupDir" 

                RecursiveDir "$file" "$backup_file"

        else

            echo "File $(basename "$file") is missing. Let's add it to the backup."

            checkModeM cp -a "$file" "$backupDir"

            echo "cp -a "$file" $backupDir" 
        fi
        
    done
}

# Chama a função principal de backup com os diretórios fornecidos
accsBackup  