#!/bin/bash

#echo "What's the path to the Backup Directory?"
#read backupDir
#echo "What's the path to the Directory that you want to backup? (it can only have files)"
#read backupDir

#################IMPORTANTE############## Os comentários foram feitos pelo copilot

# Variáveis para armazenar os modos e opções
checkMode=false;
tfile="";
regex="";

pathtoDir="$1";
backupDir="$2";

# Definição das opções aceitas pelo script
optS=":cb:r:"  

# Processamento das opções passadas na linha de comando
while getopts ${optS} opt; do
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

# Remove as opções processadas da lista de argumentos.
#################IMPORTANTE##############
shift $((OPTIND - 1)) #O copilot disse-me para adicionar isto mas não sei bem o que faz, então...

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

    return 0;

  fi

  return 1;

}

# Função para executar ou apenas exibir comandos com base no modo de verificação.
#################IMPORTANTE############## Ainda não implementei esta função!!!
function checkModeM(){

    if $checkMode; then

        echo "$@";

    else

        eval "$@"

    fi

}

# Função principal para realizar o backup
function accsBackup(){

    local pathtoDir="$1"

    local backupDir="$2"

    # Cria o diretório de backup se ele não existir e se não estiver no modo de verificação
    if [ ! -d "$backupDir" ] && [ "$checkMode" == false ]; then

        echo "Creating Backup Directory"

        mkdir -p $backupDir;

        echo "mkdir -p $backupDir";

        lastDate=$(date +'%Y%m%d_%H%M%S');

        backupFilename="backup_${lastDate}.tar.gz";

        tar czf "${backupDir}/${backupFilename}" $pathtoDir;

        tar -tzf "${backupDir}/${backupFilename}"

        echo "Backup created: ${backupDir}/${backupFilename}";
    
    else
    
        echo "Backup Directory Already Exists";
    
    fi

    ###

    # Verifica se o diretório de backup está vazio
    if find $backupDir -empty -type d; then
        
        if [ "$checkMode" == false ]; then

            cp -a $pathtoDir/. $backupDir;

            echo "cp -a $pathtoDir/. $backupDir";

        fi

    else

        echo "Files that are in the Directory we want to backup";

        ls -l $pathtoDir;

        echo "Files in the Backup Directory";

        ls -l $backupDir;

        RecursiveDir "$pathtoDir" "$backupDir";

    fi
}

# Função recursiva para copiar arquivos e diretórios
function RecursiveDir(){
    local pathtoDir="$1"
    local backupDir="$2"

    for file in $pathtoDir/*; do

        backup_file="$backupDir/$(basename "$file")";

        # Verifica se o arquivo não deve ser excluído e se corresponde à expressão regular
        if [ ! fileM "$file" ]  && [ regexM "$file" ]; then
        
            if [ -f "$backup_file" ]; then

                date_file=$(ls -l "$file" | awk '{print $6}');

                backup_date=$(ls -l "$backup_file" | awk '{print $6}');

                if [ "$date_file" == "$backup_date" ]; then

                    echo "File $(basename "$file") is up-to-date."

                else

                    echo "File $(basename "$file") has a different modification date.";

                    cp -a "$file" $backupDir;

                    echo "cp -a "$file" $backupDir" ;

                fi

            elif [ -d "$file" ]; then

                    cp -a "$file" $backupDir;

                    echo "cp -a "$file" $backupDir" ;

                    RecursiveDir "$file" "$backup_file";

            else

                echo "File $(basename "$file") is missing. Let's add it to the backup.";

                cp -a "$file" $backupDir;

                echo "cp -a "$file" $backupDir" ;
            fi
        fi

    done
}

# Chama a função principal de backup com os diretórios fornecidos
accsBackup  
