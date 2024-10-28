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

        if [ -f "$file2" ]; then

            fileList+=("$file2")
    
        elif [ -d "$file2" ]; then

            fileT "$file2"

        fi
    done
}

# Função para verificar se um ficheiro deve ser excluído
function fileM() {
    for item in "${fileList[@]}"; do
        if [[ "$1" == "$item" ]]; then
            
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

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){

    local srcDir="$1";

    local destDir="$2";

    for file in "$srcDir"/*; do

        backup_file="$destDir/$(basename "$file")"

        if fileM "$file" ; then

            continue
        
        fi

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

                echo "$(basename "$file") is missing. Let's add it to the backup."

                checkModeM cp -a "$file" "$destDir"

                echo "cp -a "$file" $destDir" 

            fi

        elif [ -d "$file" ]; then

                echo "$(basename "$file") is missing. Let's add it to the backup."

                checkModeM cp -a "$file" "$destDir"

                echo "cp -a $file $destDir" 

                RecursiveDir "$file" "$backup_file"

        fi
        
    done
}
# Chama a função principal de backup com os diretórios fornecidos
accsBackup  

#    for file2 in "$destDir"/*; do
#        if [ -f "$file2" ]; then
#
#            if [ ! -e "$file2" ]; then 
#
#                rm "$file2"
#
#            fi
#        fi
#        if [ -d ]
#    done