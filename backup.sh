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

                    fileT "$LINE"  # Chama a função para tratar diretórios recursivamente

                fi

                fileList+=("$LINE")  # Adiciona arquivo/diretório à lista


            done < "$tfile"

            for item in "${fileList[@]}"; do
        
                echo "$item"
            
            done
            
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

# Função para verificar se um ficheiro deve ser excluído
function fileM() {
    local file=$1

    for item in "${
    fileList[@]}"; do
        
        if [[ "$item" == "$file" ]]; then
            
            return 0  # O ficheiro está na lista de exclusão

        fi
        
    done
    return 1
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

            RecursiveDir "$pathtoDir/." "$backupDir"

    else

        echo "Files that are in the Directory we want to backup"

        checkModeM ls -l $pathtoDir

        echo "Files in the Backup Directory"

        checkModeM ls -l $backupDir

        RecursiveDir "$pathtoDir" "$backupDir"

    fi
}

function Delete() {
    local destDir="$1"   # Backup directory
    local pathDir="$2"   # Source directory

    for backupFile in "$destDir"/*; do

        srcFile="$pathDir/$(basename "$backupFile")"

        if [ -f "$backupFile" ]; then
            # If the file exists in backup but not in source, delete it
            if [ ! -e "$srcFile" ]; then
                checkModeM rm -rf "$backupFile"
                echo "Removing $backupFile as it's not in the source directory"
            fi

        elif [ -d "$backupFile" ]; then
            
            if [ ! -e "$srcFile" ]; then
                
                checkModeM rm -rf "$backupFile"

                echo "Removing directory $backupFile as it's not in the source directory"

            else
                
                Delete "$backupFile" "$srcFile"
            fi
        fi
    done
}

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){

    local srcDir="$1";

    local destDir="$2";

    for file in "$srcDir"/*; do

        if fileM "$file"; then

            continue
        
        fi

        backup_file="$destDir/$(basename "$file")"

        if [ -f "$file" ]; then

            if [ -f "$backup_file" ]; then

                if regexM "$file" ; then

                    continue
                
                fi

                date_file=$(stat -c %y "$file")

                backup_date=$(stat -c %y "$backup_file")

                if [ "$date_file" == "$backup_date" ]; then

                    echo "$(basename "$file") is up-to-date."

                else

                    echo "$(basename "$file") has a different modification date."

                    checkModeM cp -a "$file" "$destDir"

                    echo "cp -a "$file" $destDir" 

                fi
            else

                checkModeM cp -a "$file" "$destDir"

                echo "cp -a "$file" $destDir" 

            fi

        elif [ -d "$file" ]; then

            if [ -e "$backup_file" ]; then

                RecursiveDir "$file" "$backup_file"

            else

                checkModeM cp -a "$file" "$destDir"

                echo "cp -a $file $destDir" 

                RecursiveDir "$file" "$backup_file"

            fi

        fi
        
    done

    Delete "$backupDir" "$pathtoDir"

}
# Chama a função principal de backup com os diretórios fornecidos
accsBackup  
