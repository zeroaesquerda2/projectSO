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
            echo "Warning: Exclusion file '$tfile' does not exist."
            ((warnings++)) 
        fi

    ;;

    r)
        # Define a expressão regular para filtragem de ficheiros
        regex="$OPTARG"

    ;;

    ?)
        # Exibe mensagem de erro para opções inválidas
        echo "Invalid option: -${OPTARG}."
        ((warnings++))
        exit 1

    ;;

    esac
done



# Função para verificar se um ficheiro deve ser excluído
function fileM() {
    local file=$1

    for item in "${fileList[@]}"; do
        
        if [[ "$file" == "$item" ]]; then
            
            return 1  # O ficheiro está na lista de exclusão

        fi
    
    done

    return 0
}

# Função para verificar se um ficheiro corresponde à expressão regular
function regexM(){
    if [ -n "$regex" ] && [[ ! "$1" =~ "$regex" ]]; then

        return 1
    
    else

        return 0

    fi
}

# Função para executar ou apenas exibir comandos com base no modo de verificação.
function checkModeM(){
    if [[ "$checkMode" == false ]]; then

        "$@"

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

        checkModeM mkdir -p "$backupDir" || ((errors++))

        echo "mkdir -p $backupDir"
    
    else
    
        echo "Backup Directory Already Exists"
        ((warnings++))
    
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

    # o print da funcao summary depois do processamento
    printSummary "$pathtoDir"
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

                echo "Removing $backupFile as it's not in the source directory"
                ((warnings++))
                ((deletedFiles++))
                deletedSize=$((deletedSize + fileSize))
            else
                    echo "Failed to delete file '$backupFile'."
                    ((errors++))
            fi

        elif [ -d "$backupFile" ]; then
            
            if [ ! -e "$srcFile" ]; then
                 local dirSize=$(du -sb "$backupFile" | cut -f1)
                if checkModeM rm -rf "$backupFile"; then
                    echo "Removing directory $backupFile as it's not in the source directory"
                    ((deletedFiles++))
                    deletedSize=$((deletedSize + dirSize))
                else
                    echo "Failed to delete directory '$backupFile'."
                    ((errors++))
                fi
            else
                
                Delete "$backupFile" "$srcFile"
            fi
        fi
    done
}

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){
    local srcDir="$1"

    local destDir="$2" 

    if [ ! -d "$srcDir" ]; then

        return 1

    fi

    for file in "$srcDir"/*; do

        if ! regexM "$(basename "$file")" ; then

            continue
                    
        fi

        if fileM "$(basename "$file")"; then

            backup_file="$destDir/$(basename "$file")"

            if [ -f "$file" ]; then
            
                if [ -f "$backup_file" ]; then

                    date_file=$(stat -c %y "$file")

                    backup_date=$(stat -c %y "$backup_file")

                    if [ "$date_file" == "$backup_date" ]; then

                        echo "File $(basename "$file") is up-to-date."

                    else

                        echo "File $(basename "$file") has a different modification date."
                        
                        local fileSize=$(stat -c%s "$file")

                        if checkModeM cp -a "$file" "$destDir"; then
                            ((updatedFiles++))
                            copiedSize=$((copiedSize + fileSize))
                        else
                            ((errors++))
                        fi

                        echo "cp -a "$file" $destDir" 

                    fi
                
                else

                    checkModeM cp -a "$file" "$destDir"

                    echo "cp -a "$file" $destDir" 

                fi

            elif [ -d "$file" ]; then

                if [ -d "$backup_file" ]; then  

                    RecursiveDir "$file" "$backup_file"

                else

                    if checkModeM cp -a "$file" "$destDir"; then
                        ((copiedFiles++))
                    else
                        ((errors++))
                    fi

                    echo "cp -a $file $destDir" 

                    RecursiveDir "$file" "$backup_file"

                else

                    
                    local fileSize=$(stat -c%s "$file")

                    if checkModeM mkdir -p "$destDir/$(basename "$file")"; then
                        ((copiedFiles++))
                        copiedSize=$((copiedSize + fileSize))
                    else
                        ((errors++))
                    fi

                    echo "mkdir -p $file $destDir"

                    RecursiveDir "$file" "$destDir/$(basename "$file")"
                fi
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

    echo "While backuping $dirName: $errors Errors; $warnings Warnings; $updatedFiles Updated; $copiedFiles Copied (${copiedSize}B); $deletedFiles Deleted (${deletedSize}B)"

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
accsBackup  "$pathtoDir" "$backupDir"
