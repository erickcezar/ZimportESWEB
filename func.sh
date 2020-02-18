#!/bin/bash

# Funcoes e variaves
INFO_TEXT="printf '\e[1;33m%s\e[0m\n'" #Amarelo
ERROR_TEXT="printf '\e[1;31m%s\e[0m\n'" #Vermelho
NORMAL_TEXT="printf '\e[1;34m%-6s\e[m\n'" #Azul
CHOICE_TEXT="printf '\e[1;32m%s\e[0m\n'" #Verde
NO_COLOUR="'\e[0m'" #Branco
WORKDIR=`pwd`"/export"

## Testando usuário zimbra
Run_as_Zimbra()
{
if [ "$(whoami)" == "zimbra" ]; then
    $INFO_TEXT "OK: Executando como Zimbra."
	   else
    $ERROR_TEXT "ERRO: Esse comando deve ser executado como Zimbra."
		exit 1
fi
}
##

##
test_exec()
{
read -p "Continuar (sim/nao)?" choice
	case "$choice" in
		y|Y|yes|s|S|sim ) $NORMAL_TEXT "Iniciando utilitario";;
		n|N|no|nao ) exit 0;;
		* ) test_exec ;;
	esac
}
##

##
separator_char()
{
echo ++++++++++++++++++++++++++++++++++++++++
}
##

##
Check_Command()
{
for i in "${COMANDOS[@]}"
	do
	# do whatever on $i
		type $i >/dev/null 2>/dev/null
		if [ $? == 0 ]; then
			$INFO_TEXT "OK: comando $i existente."
			separator_char
		else
		   	$ERROR_TEXT "ERRO: O comando $i nao foi encontrado, abortando execucao."
		   	exit 1
		fi
	done
}
##

##
Check_Directory()
{
if [ ! -d "$DIRETORIO" ]; then
	$ERROR_TEXT "ERRO: O diretorio $DIRETORIO nao existe, abortando execucao."
		exit 1 
else
	$INFO_TEXT "OK: Diretorio $DIRETORIO existente."
fi
}

##
Enter_New_Hostname()
{
read -p "Informe o novo hostname do servidor Zimbra : " userInput


if [[ -z "$userInput" ]]; then
	printf '%s\n' ""
	Enter_New_Hostname
else
	TEST_FQDN=`echo $userInput | awk -F. '{print NF}'`
	if [ ! $TEST_FQDN -ge 2 ]; then
		$ERROR_TEXT "ERRO: O hostname informado nao e um FQDN valido"
		Enter_New_Hostname
	fi
OLD_HOSTNAME="$zimbra_server_hostname"
NEW_HOSTNAME="$userInput"
$CHOICE_TEXT "Hostname informado: $NEW_HOSTNAME"
fi
}
##


##
Enter_Domain()
{
read -p "Informe o dominio a ser migrado : " userInput


if [[ -z "$userInput" ]]; then
	printf '%s\n' ""
	Enter_Domain
else
	TEST_DOMAIN=`echo $userInput | awk -F. '{print NF}'`
	zmprov gd $userInput >/dev/null 2>/dev/null
	if [ $? -ne 0 ] || [ $TEST_DOMAIN -lt 2 ]; then
		$ERROR_TEXT "ERRO: O dominio informado nao existe"
		exit 1
	fi
DOMAIN="$userInput"
$CHOICE_TEXT "Dominio informado: $DOMAIN"
fi
}
##

##
Replace_Hostname()
{   
#$INFO_TEXT "Modificar hostname"
read -p "O Hostname do servidor do Zimbra sera alterado (sim/nao)?" choice
   case "$choice" in
   y|Y|yes|s|S|sim ) 
    $CHOICE_TEXT "O Hostname do servidor sera alterado."
        Enter_New_Hostname 
        Execute_Replace_Hostname
        ;;
   n|N|no|nao ) $CHOICE_TEXT "Sera mantido o hostname do servidor.";;
   * ) Replace_Hostname ;;
esac
}
##

Execute_Replace_Hostname()
{
sed -i s/$OLD_HOSTNAME/$NEW_HOSTNAME/g $DESTINO/CONTAS.ldif
sed -i s/$OLD_HOSTNAME/$NEW_HOSTNAME/g $DESTINO/LISTAS.ldif
}

##
Clear_Workdir()
{
rm -f $WORKDIR/lista_contas.ldif
rm -fr $WORKDIR/alias
}
##
