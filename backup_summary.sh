#!/bin/bash

# Variáveis para armazenar os modos e opções
checkMode=false;
tfile="";
regex="";

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

# Função para verificar se um ficheiro corresponde à expressão regular
function regexM(){
    if [ -n "$regex" ] && [[ ! "$1" =~ $regex ]]; then

        return 1;

    fi
    return 0;
}

# Função para verificar se um ficheiro deve ser excluído
function fileM(){
  if [ -n "$tfile" ] && grep -qxF "$(basename "$1")" "$tfile"; then
        
        return 1

    fi
    return 0
}

# Função para executar ou apenas exibir comandos com base no modo de verificação.
function checkModeM(){
    if [ $checkMode == false ]; then

        "$@";

    fi
}

# Remove as opções processadas da lista de argumentos.
shift $((OPTIND - 1)) 

pathtoDir="$1";
backupDir="$2";

# Função principal para realizar o backup
function accsBackup(){

    # Cria o diretório de backup se ele não existir e se não estiver no modo de verificação
    if [ ! -d "$backupDir" ]; then

        echo "Creating Backup Directory"

        checkModeM mkdir -p "$backupDir";

        echo "mkdir -p $backupDir";
    
    else
    
        echo "Backup Directory Already Exists";
    
    fi

    # Verifica se o diretório de backup está vazio
    if find $backupDir -empty -type d; then

            checkModeM cp -a $pathtoDir/. $backupDir;

            echo "cp -a $pathtoDir/. $backupDir";

    else

        echo "Files that are in the Directory we want to backup";

        checkModeM ls -l $pathtoDir;

        echo "Files in the Backup Directory";

        checkModeM ls -l $backupDir;

        RecursiveDir "$pathtoDir" "$backupDir";

    fi
}

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){

    for file in $pathtoDir/*; do

        backup_file="$backupDir/$(basename "$file")";

        # Verifica se o arquivo não deve ser excluído e se corresponde à expressão regular
        if [ fileM "$file" = 0 ]  && [ regexM "$file" ]; then
        
            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');

                if [ "$date_file" == "$backup_date" ]; then

                    echo "File $(basename "$file") is up-to-date."

                else

                    echo "File $(basename "$file") has a different modification date.";

                    checkModeM cp -a "$file" $backupDir;

                    echo "cp -a "$file" $backupDir" ;

                fi

            elif [ -d "$file" ]; then

                    checkModeM cp -a "$file" $backupDir;

                    echo "cp -a "$file" $backupDir" ;

                    RecursiveDir "$file" "$backup_file";

            else

                echo "File $(basename "$file") is missing. Let's add it to the backup.";

                checkModeM cp -a "$file" $backupDir;

                echo "cp -a "$file" $backupDir" ;
            fi
        fi

    done
}

# Chama a função principal de backup com os diretórios fornecidos
accsBackup  
