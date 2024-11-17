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

            while IFS= read -r LINE || [ -n "$LINE" ]; do
                if [ -n "$LINE" ]; then # verifica se a linha sta vazia
                    fileList+=("$(basename "$LINE")")   # Adiciona o nome base à lista de exclusão
                else
                    echo "Warning: Found an empty line in the exclusion file."
                    ((warnings++))
                fi
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

# Função para verificar se um ficheiro deve ser excluído
function fileM() {
    local file=$1

    for item in "${fileList[@]}"; do
        
        if [[ "$file" == "$item" ]]; then
            echo "Warning: $file is in the exclusion list and will not be backed up."
            ((warnings++))
            return 1  # O ficheiro está na lista de exclusão

        fi
    
    done

    return 0
}

# Função para verificar se um ficheiro corresponde à expressão regular
function regexM(){
    if [ -n "$regex" ] && [[ ! "$1" =~ "$regex" ]]; then
        echo "Warning: $1 does not match the regex filter and will be skipped."
        ((warnings++))
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

# Esta função verifica se existe espaço suficiente na diretoria destino
function checkSpace() {
    local srcDir="$1"
    local destDir="$2"

    # Calcula o tamanho total do diretório de origem em bytes
    local srcSize=$(du -sb "$srcDir" 2>/dev/null | awk '{print $1}') # awk '{print $1}' isto é para não nos
    if [ -z "$srcSize" ]; then                                       # passar informação desnecessaria
        echo "Error: Unable to calculate the size of the source directory. Exiting."
        ((errors++))
        exit 1
    fi

    # Obtém o espaço disponível no destino em bytes
    local availableSpace=$(df -B1 "$destDir" | tail -1 | awk '{print $4}') # o mesmo que em cima
    if [ -z "$availableSpace" ]; then
        echo "Error: Unable to determine available space on the destination. Exiting."
        ((errors++))
        exit 1
    fi

    # Compara o espaço disponível com o tamanho do diretório de origem
    if [ "$availableSpace" -ge "$srcSize" ]; then
        return 0
    else
        echo "Warning: Not enough space for the backup."
        ((warnings++))
        echo "Source size: $((srcSize / 1024 / 1024)) MB, Available space: $((availableSpace / 1024 / 1024)) MB"
        return 1
    fi
}

# Função principal para realizar o backup
function accsBackup(){

    local pathtoDir="$1"
    local backupDir="$2"

    # Verifica se há espaço suficiente no destino
    if ! checkSpace "$pathtoDir" "$backupDir"; then
        echo "Error: Insuficient space on backup directory. Exiting."
        exit 1
    fi

    # Cria o diretório de backup se ele não existir e se não estiver no modo de verificação
    if [ ! -d "$backupDir" ]; then

        checkModeM mkdir -p "$backupDir" || ((errors++))
    
    fi

    RecursiveDir "$pathtoDir" "$backupDir"
    printSummary "$pathtoDir"
    Delete "$backupDir" "$pathtoDir"
    # o print da funcao summary depois do processamento
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
                    echo "Error: Failed to delete directory '$backupFile'."
                    ((errors++))
                fi
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

                        continue

                    else
                        local fileSize=$(stat -c%s "$file")

                        checkModeM cp -a "$file" "$destDir"
                        ((updatedFiles++))
                        copiedSize=$((copiedSize + fileSize))

                        echo "cp -a $file $backup_file" 

                    fi
                else

                    checkModeM cp -a "$file" "$destDir"
                    ((copiedFiles++))
                    copiedSize=$((copiedSize + fileSize))
                    echo "cp -a $file $backup_file"
                    

                fi

            elif [ -d "$file" ]; then
                if [ ! -x "$file" ]; then
                    echo "Error: No execute permission for directory $file."
                    ((errors++))
                    continue
                else
                    checkModeM mkdir -p "$backup_file" 
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

    #printSummary "$srcDir"

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
accsBackup "$pathtoDir" "$backupDir"