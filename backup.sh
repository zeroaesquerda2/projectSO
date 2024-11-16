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

            while IFS= read -r LINE || [ -n "$LINE" ]; do
                if [ -n "$LINE" ]; then # verifica se a linha sta vazia
                    fileList+=("$(basename "$LINE")")   # Adiciona o nome base à lista de exclusão
                fi
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
        echo "Sufficient space available for the backup."
        return 0
    else
        echo "Warning: Not enough space for the backup."
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
    local destDir="$1"   # Diretoria de destino
    local pathDir="$2"   # Diretoria de origem

    for backupFile in "$destDir"/*; do

        srcFile="$pathDir/$(basename "$backupFile")"

        if [ -f "$backupFile" ]; then
            # Se o ficheiro existir no backup mas não na source, dar delete no ficheiro
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

                if [ -d "$backup_file" ]; then  

                    RecursiveDir "$file" "$backup_file"

                else

                    checkModeM mkdir -p "$destDir/$(basename "$file")"

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
# Chama a função principal de backup com os diretórios fornecidos
accsBackup "$pathtoDir" "$backupDir"
