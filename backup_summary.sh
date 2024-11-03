#!/bin/bash
# Variáveis para armazenar os modos e opções
checkMode=false
tfile=""
regex=""
fileList=()

# Contadores
errors=0
warnings=0
updatedFiles=0
copiedFiles=0
copiedSize=0
deletedFiles=0
deletedSize=0

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

                fileList+=("$(basename "$LINE")")  # Adiciona arquivo/diretório à lista

            done < "$tfile"

            for item in "${fileList[@]}"; do
        
                echo "$item"
            
            done

            else
                echo "Error: Exclusion file '$tfile' does not exist or is not accessible."
                ((errors++))
            
        fi

    ;;

    r)
        # Define a expressão regular para filtragem de ficheiros
        regex="$OPTARG"

    ;;

    ?)
        # Exibe mensagem de erro para opções inválidas
        echo "Invalid option: -${OPTARG}."
        ((errors++))
        exit 1

    ;;

    esac
done

function fileM() {
    local file=$1

    for item in "${fileList[@]}"; do
        
        if [[ "$file" == "$item" ]]; then
            ((warnings++))
            echo "Warning: $file is in the exclusion list and will not be backed up."
            return 1  # O ficheiro está na lista de exclusão

        fi
    
    done

    return 0
}

# Função para verificar se um ficheiro corresponde à expressão regular
function regexM(){
    if [ -n "$regex" ] && [[ ! "$1" =~ "$regex" ]]; then
        ((warnings++))
        echo "Warning: $1 does not match the regex filter and will be skipped."
        return 1
    
    else

        return 0

    fi
}

# Função para executar ou apenas exibir comandos com base no modo de verificação.
function checkModeM(){
    if [[ "$checkMode" == false ]]; then
        "$@"
        if [ $? -ne 0 ]; then
            echo "Error: Command '$@' failed."
            ((errors++))
        fi
    fi
}

# Remove as opções processadas da lista de argumentos.
shift $((OPTIND - 1)) 

pathtoDir="$1"
backupDir="$2"

if [ ! -d "$pathtoDir" ]; then

    echo "Error: O diretório de trabalho '$pathtoDir' não existe."
    ((errors++))
    exit 1

fi

# Função principal para realizar o backup
function accsBackup(){

    local pathtoDir="$1"
    local backupDir="$2"

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
                local fileSize=$(stat -c%s "$backupFile")
                checkModeM rm -rf "$backupFile"
                ((deletedFiles++))
                deletedSize=$((deletedSize + fileSize))
                echo "Removing $backupFile as it's not in the source directory"
            fi

        elif [ -d "$backupFile" ]; then
            
            if [ ! -e "$srcFile" ]; then
                local dirSize=$(du -sb "$backupFile" | cut -f1)
                checkModeM rm -rf "$backupFile"
                ((deletedFiles++))
                deletedSize=$((deletedSize + dirSize))
                echo "Removing directory $backupFile as it's not in the source directory"

            else
                
                Delete "$backupFile" "$srcFile"
            fi
        else
            echo "Error: Unable to access $backupFile."
            ((errors++))
        fi
    done
}

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){

    local srcDir="$1";

    local destDir="$2";

    if [ ! -d "$srcDir" ]; then
        echo "Error: Directory $srcDir does not exist or is inaccessible."
        ((errors++))
        return 1

    fi

    for file in "$srcDir"/*; do

        if ! regexM "$(basename "$file")" ; then

            continue
                    
        fi

        if fileM "$(basename "$file")"; then

            backup_file="$destDir/$(basename "$file")"

            if [ -f "$file" ]; then
                if [ ! -r "$file" ]; then
                    echo "Error: No read permission for file $file."
                    ((errors++))
                    continue
                fi

                local fileSize=$(stat -c%s "$file")

                if [ -f "$backup_file" ]; then

                    date_file=$(stat -c %y "$file")

                    backup_date=$(stat -c %y "$backup_file")

                    if [ "$date_file" == "$backup_date" ]; then

                        echo "$(basename "$file") is up-to-date."

                    else

                        echo "$(basename "$file") has a different modification date."

                        local fileSize=$(stat -c%s "$file")

                        checkModeM cp -a "$file" "$destDir"
                        ((updatedFiles++))
                        copiedSize=$((copiedSize + fileSize))
                        echo "Updateing $file in $destDir"
                        echo "cp -a $file $destDir" 

                    fi

                else

                    checkModeM cp -a "$file" "$destDir"
                    ((copiedFiles++))
                    copiedSize=$((copiedSize + fileSize))
                    echo "cp -a $file $destDir"
                    echo "Updated $file to $destDir"

                fi

            elif [ -d "$file" ]; then
                if [ ! -x "$file" ]; then
                    echo "Error: No execute permission for directory $file."
                    ((errors++))
                    continue
                fi

                if [ -z "$(ls -A "$file")" ]; then
                    ((warnings++))
                    echo "Warning: Directory $file is empty and will not be copied."
                else
                    checkModeM mkdir -p "$backup_file"
                    echo "mkdir -p $file $destDir" 
                    RecursiveDir "$file" "$backup_file"
                fi
            else
                echo "Error: $file could not be accessed."
                ((errors++))

            fi

        else 

            continue

        fi
    done

    Delete "$backupDir" "$pathtoDir"

}


# Função para imprimir o sumário
function printSummary() {
    local dirName="$1" # nome da diretoria origem (onde estao os ficheiros para backup)

    echo "While backing up $dirName: $errors Errors; $warnings Warnings; $updatedFiles Updated; $copiedFiles Copied (${copiedSize}B); $deletedFiles Deleted (${deletedSize}B)"

    # Reset dos contadores
    errors=0
    warnings=0
    updatedFiles=0
    copiedFiles=0
    deletedFiles=0
    copiedSize=0
    deletedSize=0
}

# Chama a função principal de backup com os diretórios fornecidos
accsBackup "$pathtoDir" "$backupDir"

# o print da funcao summary depois do processamento
printSummary "$pathtoDir"